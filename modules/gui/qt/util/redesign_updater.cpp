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
#include <QProcess>
#include <QRegularExpression>
#include <QSettings>
#include <QStandardPaths>
#include <QUrl>

#include <algorithm>

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

} // namespace

RedesignUpdater::RedesignUpdater(qt_intf_t *intf, QObject *parent)
    : QObject(parent)
    , m_intf(intf)
{
    m_startupTimer.setSingleShot(true);
    m_startupTimer.setInterval(8000);
    connect(&m_startupTimer, &QTimer::timeout, this, [this]() {
        const QDateTime last = QDateTime::fromString(
            m_intf->mainSettings->value(keyLastCheck).toString(), Qt::ISODate);
        if (!last.isValid() || last.secsTo(QDateTime::currentDateTimeUtc()) > 20 * 3600)
            check(false);
    });
    if (var_InheritBool(m_intf, "redesign-update-check") && httpRequestSupported())
        m_startupTimer.start();
}

QString RedesignUpdater::currentVersion() const
{
    return QStringLiteral(VLC_REDESIGN_VERSION);
}

QString RedesignUpdater::repositoryUrl() const
{
    return QStringLiteral(VLC_REDESIGN_REPO_URL);
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
    // The installer leaves its uninstaller next to vlc.exe; a portable copy
    // is updated by downloading the new zip instead
    return QFileInfo::exists(QCoreApplication::applicationDirPath() + QStringLiteral("/unins000.exe"));
#else
    return false;
#endif
}

bool RedesignUpdater::canInstall() const
{
    return isInstalledCopy() && !m_installerUrl.isEmpty() && !m_sumsUrl.isEmpty();
}

bool RedesignUpdater::showBanner() const
{
    if (m_dismissed || m_aboutOpen)
        return false;
    switch (m_state) {
    case Available:
        return m_manual || m_latestVersion != m_intf->mainSettings->value(keySkipped).toString();
    case Downloading:
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
    if (!open && m_manual && m_state != Downloading)
        m_dismissed = true;
    emit stateChanged();
}

void RedesignUpdater::setState(State state, const QString &error)
{
    m_state = state;
    m_error = error;
    emit stateChanged();
}

void RedesignUpdater::check(bool manual)
{
    if (m_state == Checking || m_state == Downloading)
        return;
    m_manual = manual;
    m_dismissed = false;
    if (!httpRequestSupported()) {
        setState(Failed, qtr("This build cannot check for updates."));
        return;
    }
    setState(Checking);
    httpRequestAsync(this, githubRequest(QString::fromLatin1(latestReleaseApi), 1024 * 1024, 20000),
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
    m_sumsUrl.clear();
    for (const QJsonValue asset : release.value(QLatin1String("assets")).toArray()) {
        const QJsonObject a = asset.toObject();
        const QString name = a.value(QLatin1String("name")).toString();
        const QString url = a.value(QLatin1String("browser_download_url")).toString();
        if (name.endsWith(QLatin1String("-win64-setup.exe"), Qt::CaseInsensitive)) {
            m_installerUrl = url;
            m_installerName = name;
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
    if (m_state == Downloading)
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
    setState(Downloading);
    // The installer is only run if it matches the checksum published with it
    httpRequestAsync(this, githubRequest(m_sumsUrl, 64 * 1024, 30000),
                     [this](const HttpResponse &response) {
        QString expected;
        if (response.error.isEmpty() && response.status == 200) {
            for (const QString &line : QString::fromUtf8(response.body).split('\n')) {
                QStringList parts = line.trimmed().split(QRegularExpression(QStringLiteral("\\s+")));
                // "<hash>  <name>", or "<hash> *<name>" in binary mode
                if (parts.size() == 2 && parts[1].remove('*') == m_installerName)
                    expected = parts[0].toLower();
            }
        }
        if (expected.size() != 64) {
            setState(Failed, qtr("The update's checksum is missing; download it from the release page instead."));
            return;
        }
        download(expected);
    });
}

void RedesignUpdater::download(const QString &expectedSha256)
{
    httpRequestAsync(this, githubRequest(m_installerUrl, 512 * 1024 * 1024, 30 * 60 * 1000),
                     [this, expectedSha256](const HttpResponse &response) {
        if (!response.error.isEmpty() || response.status != 200) {
            setState(Failed, qtr("The download failed. Try again, or download it from the release page."));
            return;
        }
        const QString actual = QString::fromLatin1(
            QCryptographicHash::hash(response.body, QCryptographicHash::Sha256).toHex());
        if (actual != expectedSha256) {
            setState(Failed, qtr("The downloaded installer doesn't match its checksum, so it wasn't run."));
            return;
        }
        const QString dir = QStandardPaths::writableLocation(QStandardPaths::TempLocation)
                            + QStringLiteral("/vlc-redesign-update");
        QDir().mkpath(dir);
        const QString path = dir + QLatin1Char('/') + m_installerName;
        QFile file(path);
        if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)
            || file.write(response.body) != response.body.size()) {
            setState(Failed, qtr("The installer couldn't be saved to %1.").arg(QDir::toNativeSeparators(dir)));
            return;
        }
        file.close();
        launchInstaller(path);
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
