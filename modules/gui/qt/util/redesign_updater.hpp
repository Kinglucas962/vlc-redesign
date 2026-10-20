/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *****************************************************************************/
#pragma once

#include <QObject>
#include <QString>
#include <QTimer>

#include "qt.hpp"

// Updates of VLC Redesign from its GitHub releases (not VideoLAN's feed,
// which offers the official VLC). Checks the latest release at startup
// (option redesign-update-check, at most once a day) or on request, and
// offers to open the release page or, for an installed copy, to download
// the installer, check it against the release's SHA256SUMS.txt and run it:
// it closes VLC and reopens it on the media and time that were playing.
class RedesignUpdater : public QObject
{
    Q_OBJECT

    Q_PROPERTY(State state READ state NOTIFY stateChanged FINAL)
    Q_PROPERTY(QString currentVersion READ currentVersion CONSTANT FINAL)
    Q_PROPERTY(QString latestVersion READ latestVersion NOTIFY stateChanged FINAL)
    Q_PROPERTY(QString releaseTitle READ releaseTitle NOTIFY stateChanged FINAL)
    Q_PROPERTY(QString summary READ summary NOTIFY stateChanged FINAL)
    Q_PROPERTY(QString errorText READ errorText NOTIFY stateChanged FINAL)
    Q_PROPERTY(bool canInstall READ canInstall NOTIFY stateChanged FINAL)
    Q_PROPERTY(bool manual READ manual NOTIFY stateChanged FINAL)
    Q_PROPERTY(bool showBanner READ showBanner NOTIFY stateChanged FINAL)
    // About shows the state itself: no banner while it is open
    Q_PROPERTY(bool aboutOpen READ aboutOpen WRITE setAboutOpen NOTIFY stateChanged FINAL)
    Q_PROPERTY(QString repositoryUrl READ repositoryUrl CONSTANT FINAL)

public:
    enum State {
        Idle,
        Checking,
        UpToDate,
        Available,
        Downloading,
        Failed
    };
    Q_ENUM(State)

    explicit RedesignUpdater(qt_intf_t *intf, QObject *parent = nullptr);

    State state() const { return m_state; }
    QString currentVersion() const;
    QString latestVersion() const { return m_latestVersion; }
    QString releaseTitle() const { return m_releaseTitle; }
    QString summary() const { return m_summary; }
    QString errorText() const { return m_error; }
    bool canInstall() const;
    bool manual() const { return m_manual; }
    bool showBanner() const;
    bool aboutOpen() const { return m_aboutOpen; }
    void setAboutOpen(bool open);
    QString repositoryUrl() const;

    // a < b, comparing "1.2.3" or "v1.2.3-beta.1" like semantic versions
    static bool versionLess(const QString &a, const QString &b);

public slots:
    // manual: show "up to date" and errors too, ignore a skipped version
    void check(bool manual = true);
    void openReleasePage();
    void install();
    void skipThisVersion();
    void dismiss();

signals:
    void stateChanged();

private:
    void setState(State state, const QString &error = {});
    void onRelease(int status, const QByteArray &body);
    void download(const QString &expectedSha256);
    void launchInstaller(const QString &path);
    bool isInstalledCopy() const;

    qt_intf_t *m_intf;
    QTimer m_startupTimer;
    State m_state = Idle;
    bool m_manual = false;
    bool m_dismissed = false;
    bool m_aboutOpen = false;
    QString m_latestVersion;
    QString m_releaseTitle;
    QString m_summary;
    QString m_releaseUrl;
    QString m_installerUrl;
    QString m_installerName;
    QString m_sumsUrl;
    QString m_error;
};
