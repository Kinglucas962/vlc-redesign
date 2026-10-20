/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *****************************************************************************/
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "redesign_updater.hpp"

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDateTime>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPointer>
#include <QProcess>
#include <QRegularExpression>
#include <QSettings>
#include <QStandardPaths>
#include <QThread>
#include <QtEndian>
#include <QUrl>

#include <algorithm>
#include <cstring>
#include <memory>

#include "dialogs/dialogs_provider.hpp"
#include "player/player_controller.hpp"
#include "util/http_request.hpp"
#include "util/redesign_version.hpp"

namespace {

const char latestReleaseApi[] = "https://api.github.com/repos/" VLC_REDESIGN_REPO "/releases/latest";
const char latestReleasePage[] = VLC_REDESIGN_REPO_URL "/releases/latest";
const char keyLastCheck[] = "redesign/update-last-check";
const char keySkipped[] = "redesign/update-skip";

HttpRequest githubRequest(const QString &url, qsizetype maxBytes, int timeoutMs)
{
    HttpRequest request;
    request.url = QUrl(url);
    request.maxBytes = maxBytes;
    request.timeoutMs = timeoutMs;
    // GitHub refuses API requests without a User-Agent
    request.headers.append(qMakePair(QByteArray("User-Agent"), QByteArray("VLC-Redesign/" VLC_REDESIGN_VERSION)));
    request.headers.append(qMakePair(QByteArray("Accept"), QByteArray("application/vnd.github+json")));
    return request;
}

// "v1.2.3-beta.1" -> numbers {1, 2, 3} and pre-release "beta.1"
void splitVersion(QString v, QList<int> &numbers, QString &pre)
{
    v = v.trimmed();
    if (v.startsWith('v') || v.startsWith('V'))
        v.remove(0, 1);
    const qsizetype dash = v.indexOf('-');
    pre = dash >= 0 ? v.mid(dash + 1) : QString();
    const QString core = dash >= 0 ? v.left(dash) : v;
    for (const QString &part : core.split('.'))
        numbers.append(part.toInt());
    while (numbers.size() < 3)
        numbers.append(0);
}

// The release notes in a few plain lines: the bullets of the first section
// that has some (the "Highlights"), without Markdown
QString summarise(const QString &markdown)
{
    static const QRegularExpression link(QStringLiteral("!?\\[([^\\]]*)\\]\\([^)]*\\)"));
    static const QRegularExpression emphasis(QStringLiteral("[*_`]+"));
    QStringList bullets;
    for (QString line : markdown.split('\n')) {
        line = line.trimmed();
        if (line.startsWith(QLatin1String("- ")) || line.startsWith(QLatin1String("* "))) {
            line = line.mid(2);
            line.replace(link, QStringLiteral("\\1"));
            line.remove(emphasis);
            bullets.append(line.trimmed());
            if (bullets.size() == 4)
                break;
        } else if (!bullets.isEmpty() && line.startsWith('#')) {
            break;
        }
    }
    return bullets.join('\n');
}

// The delta of a release (make-delta.py): its blocks are in the qCompress
// format, a patch is bsdiff's (control triples, differences, extra bytes)
QByteArray block(const char *blobs, qsizetype available, qint64 offset, qint64 length)
{
    if (offset < 0 || length < 4 || offset + length > available)
        return {};
    return qUncompress(reinterpret_cast<const uchar *>(blobs + offset), static_cast<qsizetype>(length));
}

bool bspatch(const QByteArray &old, const QByteArray &control, const QByteArray &diff,
             const QByteArray &extra, qint64 size, QByteArray &out)
{
    if (control.size() % 24 || size < 0)
        return false;
    out = QByteArray(static_cast<qsizetype>(size), Qt::Uninitialized);
    char *dst = out.data();
    const char *src = old.constData();
    const qint64 oldSize = old.size();
    qint64 newPos = 0, oldPos = 0, diffPos = 0, extraPos = 0;
    for (qsizetype i = 0; i < control.size(); i += 24) {
        const qint64 x = qFromLittleEndian<qint64>(control.constData() + i);
        const qint64 y = qFromLittleEndian<qint64>(control.constData() + i + 8);
        const qint64 z = qFromLittleEndian<qint64>(control.constData() + i + 16);
        if (x < 0 || y < 0 || newPos + x + y > size || diffPos + x > diff.size() || extraPos + y > extra.size())
            return false;
        // x bytes: the old ones plus the difference
        for (qint64 k = 0; k < x; ++k) {
            const qint64 o = oldPos + k;
            const char base = (o >= 0 && o < oldSize) ? src[o] : 0;
            dst[newPos + k] = static_cast<char>(base + diff.constData()[diffPos + k]);
        }
        newPos += x;
        oldPos += x;
        diffPos += x;
        memcpy(dst + newPos, extra.constData() + extraPos, static_cast<size_t>(y));
        newPos += y;
        extraPos += y;
        oldPos += z;
    }
    return newPos == size;
}

QString sha256Hex(const QByteArray &data)
{
    return QString::fromLatin1(QCryptographicHash::hash(data, QCryptographicHash::Sha256).toHex());
}

// A path of the delta, relative to VLC's folder: never out of it, never
// the user's data
bool safeRelativePath(const QString &path)
{
    return !path.isEmpty() && !path.contains(QLatin1String("..")) && !path.contains(':')
           && !path.startsWith('/') && !path.startsWith('\\')
           && !path.startsWith(QLatin1String("portable"), Qt::CaseInsensitive)
           && !path.startsWith(QLatin1String(".update"), Qt::CaseInsensitive);
}

// vlc-redesign-update.exe puts the update in place once VLC has quit: a copy
// of it, so the update can replace it too. Run once now, on the worker
// thread (it returns at once without arguments): Windows may check a new
// program for seconds when it first runs, better now than on Restart.
bool prepareHelper(const QString &dir)
{
    const QString helper = dir + QStringLiteral("/.update/vlc-redesign-update.exe");
    QFile::remove(helper);
    if (!QFile::copy(dir + QStringLiteral("/vlc-redesign-update.exe"), helper))
        return false;
    QProcess probe;
    probe.start(helper, {});
    probe.waitForFinished(30000);
    return true;
}

} // namespace

RedesignUpdater::RedesignUpdater(qt_intf_t *intf, QObject *parent)
    : QObject(parent)
    , m_intf(intf)
{
    m_startupTimer.setSingleShot(true);
    m_startupTimer.setInterval(8000);
    connect(&m_startupTimer, &QTimer::timeout, this, [this]() {
        if (m_state != Idle)
            return;
        const QDateTime last = QDateTime::fromString(
            m_intf->mainSettings->value(keyLastCheck).toString(), Qt::ISODate);
        if (!last.isValid() || last.secsTo(QDateTime::currentDateTimeUtc()) > 20 * 3600)
            check(false);
    });
    connect(qApp, &QCoreApplication::aboutToQuit, this, &RedesignUpdater::applyOnExit);
    findStagedUpdate();
    resumeAfterUpdate();
    if (var_InheritBool(m_intf, "redesign-update-check") && httpRequestSupported())
        m_startupTimer.start();
}

RedesignUpdater::~RedesignUpdater()
{
    // VLC is quitting: the interface (and this) can go before the event
    // loop ends, so aboutToQuit alone may come too late
    if (qApp && qApp->property("isDying").toBool())
        applyOnExit();
}

QString RedesignUpdater::currentVersion() const
{
    return QStringLiteral(VLC_REDESIGN_VERSION);
}

QString RedesignUpdater::repositoryUrl() const
{
    return QStringLiteral(VLC_REDESIGN_REPO_URL);
}

QString RedesignUpdater::appDir() const
{
    return QCoreApplication::applicationDirPath();
}

bool RedesignUpdater::versionLess(const QString &a, const QString &b)
{
    QList<int> na, nb;
    QString pa, pb;
    splitVersion(a, na, pa);
    splitVersion(b, nb, pb);
    for (int i = 0; i < std::max(na.size(), nb.size()); ++i) {
        const int x = i < na.size() ? na[i] : 0;
        const int y = i < nb.size() ? nb[i] : 0;
        if (x != y)
            return x < y;
    }
    // a pre-release comes before its release
    if (pa.isEmpty() != pb.isEmpty())
        return !pa.isEmpty();
    return QString::compare(pa, pb, Qt::CaseInsensitive) < 0;
}

bool RedesignUpdater::isInstalledCopy() const
{
#ifdef _WIN32
    // The installer leaves its uninstaller next to vlc.exe
    return QFileInfo::exists(appDir() + QStringLiteral("/unins000.exe"));
#else
    return false;
#endif
}

bool RedesignUpdater::appFolderWritable() const
{
#ifdef _WIN32
    // Program Files (an install for everyone) is not: the installer then
    // asks for the rights. Checked once: the properties read it often.
    if (m_writable < 0) {
        m_writable = 0;
        if (QFileInfo::exists(appDir() + QStringLiteral("/vlc-redesign-update.exe"))
            && QDir().mkpath(appDir() + QStringLiteral("/.update"))) {
            QFile probe(appDir() + QStringLiteral("/.update/write-test"));
            if (probe.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
                probe.close();
                probe.remove();
                m_writable = 1;
            }
        }
    }
    return m_writable == 1;
#else
    return false;
#endif
}

bool RedesignUpdater::smallUpdate() const
{
    return !m_deltaUrl.isEmpty() && !m_sumsUrl.isEmpty() && appFolderWritable();
}

bool RedesignUpdater::canInstall() const
{
    return smallUpdate() || (isInstalledCopy() && !m_installerUrl.isEmpty() && !m_sumsUrl.isEmpty());
}

qint64 RedesignUpdater::updateSize() const
{
    if (smallUpdate())
        return m_deltaSize;
    return canInstall() ? m_installerSize : 0;
}

bool RedesignUpdater::showBanner() const
{
    if (m_dismissed || m_aboutOpen)
        return false;
    switch (m_state) {
    case Available:
        return m_manual || m_latestVersion != m_intf->mainSettings->value(keySkipped).toString();
    case Downloading:
    case Preparing:
    case Ready:
        return true;
    case Checking:
    case UpToDate:
    case Failed:
        return m_manual;
    default:
        return false;
    }
}

void RedesignUpdater::setAboutOpen(bool open)
{
    if (open == m_aboutOpen)
        return;
    m_aboutOpen = open;
    // what a check made in About found was read there; a download goes on
    // in the banner
    if (!open && m_manual && m_state != Downloading && m_state != Preparing && m_state != Ready)
        m_dismissed = true;
    emit stateChanged();
}

void RedesignUpdater::setState(State state, const QString &error)
{
    m_state = state;
    m_error = error;
    emit stateChanged();
}

void RedesignUpdater::setProgress(double progress)
{
    if (qFuzzyCompare(progress + 1, m_progress + 1))
        return;
    m_progress = progress;
    emit progressChanged();
}

void RedesignUpdater::check(bool manual)
{
    if (m_state == Checking || m_state == Downloading || m_state == Preparing || m_state == Ready)
        return;
    m_manual = manual;
    m_dismissed = false;
    if (!httpRequestSupported()) {
        setState(Failed, qtr("This build cannot check for updates."));
        return;
    }
    setState(Checking);
    // for testing updates against a local server, not GitHub
    const QByteArray api = qgetenv("VLC_REDESIGN_UPDATE_API");
    const QString url = api.isEmpty() ? QString::fromLatin1(latestReleaseApi) : QString::fromUtf8(api);
    httpRequestAsync(this, githubRequest(url, 1024 * 1024, 20000),
                     [this](const HttpResponse &response) {
        if (!response.error.isEmpty() || response.status == 0) {
            setState(Failed, qtr("Couldn't reach GitHub. Check your connection and try again."));
            return;
        }
        onRelease(response.status, response.body);
    });
}

void RedesignUpdater::onRelease(int status, const QByteArray &body)
{
    if (status == 404) {
        // no release published yet
        setState(UpToDate);
        return;
    }
    const QJsonObject release = QJsonDocument::fromJson(body).object();
    const QString tag = release.value(QLatin1String("tag_name")).toString();
    if (status != 200 || tag.isEmpty()) {
        setState(Failed, qtr("GitHub sent an unexpected answer (%1).").arg(status));
        return;
    }
    m_intf->mainSettings->setValue(keyLastCheck, QDateTime::currentDateTimeUtc().toString(Qt::ISODate));

    m_latestVersion = tag.startsWith('v') ? tag.mid(1) : tag;
    m_releaseTitle = release.value(QLatin1String("name")).toString();
    m_summary = summarise(release.value(QLatin1String("body")).toString());
    m_releaseUrl = release.value(QLatin1String("html_url")).toString();
    m_installerUrl.clear();
    m_installerName.clear();
    m_installerSize = 0;
    m_deltaUrl.clear();
    m_deltaName.clear();
    m_deltaSize = 0;
    m_sumsUrl.clear();
    // the small update from this very version, if the release has one
    const QString deltaName = QStringLiteral("vlc-redesign-%1-delta-from-%2.vrdelta")
                                  .arg(m_latestVersion, currentVersion());
    for (const QJsonValue asset : release.value(QLatin1String("assets")).toArray()) {
        const QJsonObject a = asset.toObject();
        const QString name = a.value(QLatin1String("name")).toString();
        const QString url = a.value(QLatin1String("browser_download_url")).toString();
        const qint64 size = a.value(QLatin1String("size")).toInteger();
        if (name.endsWith(QLatin1String("-win64-setup.exe"), Qt::CaseInsensitive)) {
            m_installerUrl = url;
            m_installerName = name;
            m_installerSize = size;
        } else if (name.compare(deltaName, Qt::CaseInsensitive) == 0) {
            m_deltaUrl = url;
            m_deltaName = name;
            m_deltaSize = size;
        } else if (name.compare(QLatin1String("SHA256SUMS.txt"), Qt::CaseInsensitive) == 0) {
            m_sumsUrl = url;
        }
    }

    setState(versionLess(currentVersion(), m_latestVersion) ? Available : UpToDate);
}

void RedesignUpdater::openReleasePage()
{
    // Always the page the project names, not a URL from the release data
    QDesktopServices::openUrl(QUrl(QString::fromLatin1(latestReleasePage)));
}

void RedesignUpdater::skipThisVersion()
{
    m_intf->mainSettings->setValue(keySkipped, m_latestVersion);
    m_dismissed = true;
    emit stateChanged();
}

void RedesignUpdater::dismiss()
{
    if (m_state == Downloading || m_state == Preparing)
        return;
    m_dismissed = true;
    emit stateChanged();
}

void RedesignUpdater::install()
{
    if (!canInstall()) {
        openReleasePage();
        return;
    }
    setProgress(0);
    setState(Downloading);
    // Nothing is used unless it matches the checksum published with it
    if (smallUpdate())
        withChecksum(m_deltaName, [this](const QString &sha) { downloadDelta(sha); });
    else
        withChecksum(m_installerName, [this](const QString &sha) { downloadInstaller(sha); });
}

void RedesignUpdater::withChecksum(const QString &assetName, std::function<void(const QString &)> next)
{
    httpRequestAsync(this, githubRequest(m_sumsUrl, 64 * 1024, 30000),
                     [this, assetName, next](const HttpResponse &response) {
        QString expected;
        if (response.error.isEmpty() && response.status == 200) {
            for (const QString &line : QString::fromUtf8(response.body).split('\n')) {
                QStringList parts = line.trimmed().split(QRegularExpression(QStringLiteral("\\s+")));
                // "<hash>  <name>", or "<hash> *<name>" in binary mode
                if (parts.size() == 2 && parts[1].remove('*') == assetName)
                    expected = parts[0].toLower();
            }
        }
        if (expected.size() != 64) {
            setState(Failed, qtr("The update's checksum is missing; download it from the release page instead."));
            return;
        }
        next(expected);
    });
}

// The progress of a download, from its worker thread, at most once a percent
static std::function<void(qint64, qint64)> progressTo(RedesignUpdater *updater, qint64 announced,
                                                      std::function<void(double)> set)
{
    QPointer<RedesignUpdater> target(updater);
    auto last = std::make_shared<int>(-1);
    return [target, announced, set, last](qint64 received, qint64 total) {
        if (total <= 0)
            total = announced;
        if (total <= 0)
            return;
        const int percent = static_cast<int>(std::min<qint64>(100, received * 100 / total));
        if (percent == *last)
            return;
        *last = percent;
        if (target)
            QMetaObject::invokeMethod(target.data(), [set, percent]() { set(percent / 100.0); },
                                      Qt::QueuedConnection);
    };
}

void RedesignUpdater::downloadDelta(const QString &expectedSha256)
{
    HttpRequest request = githubRequest(m_deltaUrl, std::max<qint64>(m_deltaSize, 1) + 4 * 1024 * 1024,
                                        30 * 60 * 1000);
    request.progress = progressTo(this, m_deltaSize, [this](double p) { setProgress(p); });
    httpRequestAsync(this, std::move(request), [this, expectedSha256](const HttpResponse &response) {
        if (!response.error.isEmpty() || response.status != 200) {
            setState(Failed, qtr("The download failed. Check your connection and try again."));
            return;
        }
        setState(Preparing);
        // Checked and written on a worker thread: the interface stays responsive
        QPointer<RedesignUpdater> self(this);
        const QByteArray delta = response.body;
        const QString dir = appDir();
        const QString version = m_latestVersion;
        QThread *worker = QThread::create([self, delta, expectedSha256, dir, version]() {
            QString error;
            if (sha256Hex(delta) != expectedSha256)
                error = qtr("The update doesn't match its checksum, so it wasn't used.");
            else
                error = stageDelta(delta, dir, version);
            if (self)
                QMetaObject::invokeMethod(self.data(), [self, error]() {
                    if (!self)
                        return;
                    if (!error.isEmpty())
                        self->setState(Failed, error);
                    else
                        self->setState(Ready);
                }, Qt::QueuedConnection);
        });
        connect(worker, &QThread::finished, worker, &QObject::deleteLater);
        worker->start(QThread::LowPriority);
    });
}

QString RedesignUpdater::stageDelta(const QByteArray &delta, const QString &dir, const QString &version)
{
    if (delta.size() < 12 || !delta.startsWith("VRDELTA1"))
        return qtr("The update isn't in a format this version knows.");
    const quint32 headerSize = qFromLittleEndian<quint32>(delta.constData() + 8);
    if (12 + qint64(headerSize) > delta.size())
        return qtr("The update is damaged.");
    const QJsonObject header = QJsonDocument::fromJson(delta.mid(12, headerSize)).object();
    if (header.value(QLatin1String("format")).toInt() != 1
        || header.value(QLatin1String("to")).toString() != version
        || header.value(QLatin1String("from")).toString() != QLatin1String(VLC_REDESIGN_VERSION))
        return qtr("The update isn't for this version.");
    const char *blobs = delta.constData() + 12 + headerSize;
    const qsizetype available = delta.size() - 12 - headerSize;

    const QString work = dir + QStringLiteral("/.update");
    const QString staged = work + QStringLiteral("/staged");
    QFile::remove(work + QStringLiteral("/ready.txt"));
    QDir(staged).removeRecursively();
    if (!QDir().mkpath(staged))
        return qtr("The update can't be written in %1.").arg(QDir::toNativeSeparators(dir));

    const QString changed = qtr("A file of VLC Redesign was changed since it was installed, so the small "
                                "update can't be used: update with the installer instead.");
    for (const QJsonValue value : header.value(QLatin1String("files")).toArray()) {
        const QJsonObject file = value.toObject();
        const QString path = file.value(QLatin1String("path")).toString();
        const qint64 size = file.value(QLatin1String("size")).toInteger(-1);
        const qint64 offset = file.value(QLatin1String("offset")).toInteger(-1);
        if (!safeRelativePath(path) || size < 0)
            return qtr("The update is damaged.");
        QByteArray data;
        if (file.value(QLatin1String("kind")).toString() == QLatin1String("patch")) {
            QFile oldFile(dir + QLatin1Char('/') + path);
            if (!oldFile.open(QIODevice::ReadOnly))
                return changed;
            const QByteArray old = oldFile.readAll();
            if (sha256Hex(old) != file.value(QLatin1String("old_sha256")).toString())
                return changed;
            const QJsonArray parts = file.value(QLatin1String("parts")).toArray();
            if (parts.size() != 3)
                return qtr("The update is damaged.");
            const qint64 c = parts[0].toInteger(), d = parts[1].toInteger(), e = parts[2].toInteger();
            const QByteArray control = block(blobs, available, offset, c);
            const QByteArray diff = block(blobs, available, offset + c, d);
            const QByteArray extra = block(blobs, available, offset + c + d, e);
            if (!bspatch(old, control, diff, extra, size, data))
                return qtr("The update is damaged.");
        } else {
            data = block(blobs, available, offset, file.value(QLatin1String("length")).toInteger());
        }
        if (data.size() != size || sha256Hex(data) != file.value(QLatin1String("sha256")).toString())
            return qtr("The update is damaged: a file doesn't match its checksum.");
        const QString target = staged + QLatin1Char('/') + path;
        QDir().mkpath(QFileInfo(target).absolutePath());
        QFile out(target);
        if (!out.open(QIODevice::WriteOnly | QIODevice::Truncate) || out.write(data) != data.size())
            return qtr("The update can't be written in %1.").arg(QDir::toNativeSeparators(dir));
    }

    QStringList removed;
    for (const QJsonValue value : header.value(QLatin1String("removed")).toArray())
        if (safeRelativePath(value.toString()))
            removed.append(value.toString());
    QFile list(work + QStringLiteral("/removed.txt"));
    if (!list.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text))
        return qtr("The update can't be written in %1.").arg(QDir::toNativeSeparators(dir));
    list.write(removed.join('\n').toUtf8());
    list.close();
    if (!prepareHelper(dir))
        return qtr("The update can't be written in %1.").arg(QDir::toNativeSeparators(dir));
    // last: the update is complete
    QFile ready(work + QStringLiteral("/ready.txt"));
    if (!ready.open(QIODevice::WriteOnly | QIODevice::Truncate) || ready.write(version.toUtf8()) <= 0)
        return qtr("The update can't be written in %1.").arg(QDir::toNativeSeparators(dir));
    return {};
}

// An update staged by an earlier session (closed before it could be put in
// place, or a file was held): it is applied when VLC closes this time
void RedesignUpdater::findStagedUpdate()
{
    QFile ready(appDir() + QStringLiteral("/.update/ready.txt"));
    if (!ready.open(QIODevice::ReadOnly)) {
        // the helper of the last update, done
        QFile::remove(appDir() + QStringLiteral("/.update/vlc-redesign-update.exe"));
        return;
    }
    const QString version = QString::fromUtf8(ready.readAll()).trimmed();
    ready.close();
    if (!version.isEmpty() && versionLess(currentVersion(), version)) {
        m_latestVersion = version;
        m_state = Ready;
    } else {
        // applied already, or older than this version
        ready.remove();
        QDir(appDir() + QStringLiteral("/.update/staged")).removeRecursively();
    }
}

// VLC opened again after an update, on what was playing: it goes on where
// it was (not with :start-time, which makes the media a clip starting there)
void RedesignUpdater::resumeAfterUpdate()
{
    const int64_t seconds = var_InheritInteger(m_intf, "redesign-resume-time");
    PlayerController *player = m_intf->p_mainPlayerController;
    if (seconds <= 0 || !player)
        return;
    auto done = std::make_shared<bool>(false);
    auto seek = [player, seconds, done]() {
        if (*done || !player->isSeekable())
            return;
        *done = true;
        player->setTime(VLCTime(VLC_TICK_FROM_SEC(seconds)));
    };
    // the media may have started before the interface
    seek();
    const QMetaObject::Connection seekable = connect(player, &PlayerController::seekableChanged, this, seek);
    // no "Continue where you left off?" there: it is where it was
    auto asked = std::make_shared<QMetaObject::Connection>();
    if (player->canRestorePlayback())
        player->acknowledgeRestoreCallback();
    else
        *asked = connect(player, &PlayerController::playbackRestoreQueried, this, [player, asked]() {
            if (!player->canRestorePlayback())
                return;
            player->acknowledgeRestoreCallback();
            disconnect(*asked);
        });
    QTimer::singleShot(30000, this, [seekable, asked]() {
        disconnect(seekable);
        disconnect(*asked);
    });
}

bool RedesignUpdater::launchHelper(bool relaunch)
{
    if (m_helperStarted || m_state != Ready)
        return m_helperStarted;
    // The copy made with the update (prepareHelper)
    const QString dir = appDir();
    const QString helper = dir + QStringLiteral("/.update/vlc-redesign-update.exe");
    if (!QFileInfo::exists(helper) && !QFile::copy(dir + QStringLiteral("/vlc-redesign-update.exe"), helper))
        return false;
    QStringList args = { QStringLiteral("--pid"), QString::number(QCoreApplication::applicationPid()),
                         QStringLiteral("--app"), QDir::toNativeSeparators(dir),
                         QStringLiteral("--version"), m_latestVersion };
    if (relaunch) {
        args << QStringLiteral("--relaunch");
        // Reopen on what was playing, where it was
        PlayerController *player = m_intf->p_mainPlayerController;
        const QUrl media = player ? player->getUrl() : QUrl();
        if (media.isValid() && !media.isEmpty()) {
            args << QStringLiteral("--resume") << media.toString(QUrl::FullyEncoded);
            const int seconds = player->getTime().toMilliseconds() / 1000;
            if (seconds > 0)
                args << QStringLiteral("--time") << QString::number(seconds);
        }
    }
    m_helperStarted = QProcess::startDetached(helper, args, dir);
    if (m_helperStarted)
        msg_Dbg(m_intf, "update to %s: put in place once VLC has quit", qtu(m_latestVersion));
    else
        msg_Warn(m_intf, "update to %s: the helper couldn't be started", qtu(m_latestVersion));
    return m_helperStarted;
}

void RedesignUpdater::restartNow()
{
    if (m_state != Ready)
        return;
    if (!launchHelper(true)) {
        setState(Failed, qtr("The update couldn't be started. It will be tried again next time."));
        return;
    }
    QTimer::singleShot(200, this, []() { THEDP->quit(); });
}

void RedesignUpdater::applyOnExit()
{
    if (m_state == Ready)
        launchHelper(false);
}

void RedesignUpdater::downloadInstaller(const QString &expectedSha256)
{
    HttpRequest request = githubRequest(m_installerUrl, 512 * 1024 * 1024, 30 * 60 * 1000);
    request.progress = progressTo(this, m_installerSize, [this](double p) { setProgress(p); });
    httpRequestAsync(this, std::move(request), [this, expectedSha256](const HttpResponse &response) {
        if (!response.error.isEmpty() || response.status != 200) {
            setState(Failed, qtr("The download failed. Try again, or download it from the release page."));
            return;
        }
        setState(Preparing);
        // Checked and saved on a worker thread: the interface stays responsive
        QPointer<RedesignUpdater> self(this);
        const QByteArray body = response.body;
        const QString name = m_installerName;
        QThread *worker = QThread::create([self, body, expectedSha256, name]() {
            QString error, path;
            if (sha256Hex(body) != expectedSha256) {
                error = qtr("The downloaded installer doesn't match its checksum, so it wasn't run.");
            } else {
                const QString dir = QStandardPaths::writableLocation(QStandardPaths::TempLocation)
                                    + QStringLiteral("/vlc-redesign-update");
                QDir().mkpath(dir);
                path = dir + QLatin1Char('/') + name;
                QFile file(path);
                if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate) || file.write(body) != body.size())
                    error = qtr("The installer couldn't be saved to %1.").arg(QDir::toNativeSeparators(dir));
            }
            if (self)
                QMetaObject::invokeMethod(self.data(), [self, error, path]() {
                    if (!self)
                        return;
                    if (!error.isEmpty())
                        self->setState(Failed, error);
                    else
                        self->launchInstaller(path);
                }, Qt::QueuedConnection);
        });
        connect(worker, &QThread::finished, worker, &QObject::deleteLater);
        worker->start(QThread::LowPriority);
    });
}

void RedesignUpdater::launchInstaller(const QString &path)
{
    QStringList args = { QStringLiteral("/SILENT"), QStringLiteral("/SUPPRESSMSGBOXES"),
                         QStringLiteral("/NORESTART"), QStringLiteral("/UPDATE") };
    // Reopen on what was playing, where it was
    PlayerController *player = m_intf->p_mainPlayerController;
    const QUrl media = player ? player->getUrl() : QUrl();
    if (media.isValid() && !media.isEmpty()) {
        args << QStringLiteral("/RESUME=") + media.toString(QUrl::FullyEncoded);
        const int seconds = player->getTime().toMilliseconds() / 1000;
        if (seconds > 0)
            args << QStringLiteral("/TIME=%1").arg(seconds);
    }
    if (!QProcess::startDetached(path, args)) {
        setState(Failed, qtr("The installer couldn't be started."));
        return;
    }
    // The installer waits for VLC to close, then reopens it
    QTimer::singleShot(300, this, []() { THEDP->quit(); });
}
