; Copyright (C) 2026 VLC authors and VideoLAN
; SPDX-License-Identifier: GPL-2.0-or-later
;
; Windows installer of VLC Redesign (Inno Setup 6.7 or later), styled like
; the redesign: dark surfaces, orange accent. Built by make-release.ps1:
;   ISCC /DAppVersion=0.2.0 /DSourceDir=<package> /DOutputDir=<dist> vlc-redesign.iss
;
; Updates: a running VLC Redesign from the install folder is closed politely
; (then forced after 15 s) and opened again afterwards. The app's updater
; passes /UPDATE /RESUME=<media> /TIME=<seconds> so playback continues where
; it was; a manual run reopens the media VLC was started with.

#ifndef AppVersion
  #error Define AppVersion, e.g. /DAppVersion=0.2.0
#endif
#ifndef SourceDir
  #error Define SourceDir, the portable package folder
#endif
#ifndef OutputDir
  #define OutputDir "."
#endif

#define AppName "VLC Redesign"
#define RepoUrl "https://github.com/KuchiSofts/vlc-redesign"

[Setup]
AppId={{8F3C2A61-5B7E-4D9A-9C1E-6A2F0B4D7E15}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=KuchiSofts
AppPublisherURL={#RepoUrl}
AppSupportURL={#RepoUrl}/issues
AppUpdatesURL={#RepoUrl}/releases/latest
AppCopyright=GPL v2 or later. Interface design by Juxtopposed (CC BY 4.0). VLC is a trademark of VideoLAN.
VersionInfoVersion={#AppVersion}
VersionInfoDescription={#AppName} Setup
; Per-user by default (no administrator rights, no conflict with an
; installed official VLC); "Install for all users" moves it to Program Files.
DefaultDirName={autopf}\{#AppName}
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
DisableProgramGroupPage=yes
; Show the welcome page: it carries the artwork and the design credit
DisableWelcomePage=no
UsePreviousAppDir=yes
UninstallDisplayName={#AppName}
UninstallDisplayIcon={app}\vlc.exe
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir={#OutputDir}
OutputBaseFilename=vlc-redesign-{#AppVersion}-win64-setup
SetupIconFile=art\setup.ico
Compression=lzma2/ultra64
SolidCompression=yes
; We close VLC ourselves (and reopen it), not through the Restart Manager
CloseApplications=no
RestartApplications=no
InfoBeforeFile=notice.txt
; The redesign's look: forced dark, its background colour, its artwork
WizardStyle=modern dark hidebevels
WizardBackColor=#141414
WizardImageBackColor=#141414
WizardImageFile=art\wizard-100.png,art\wizard-125.png,art\wizard-150.png,art\wizard-175.png,art\wizard-200.png,art\wizard-250.png
WizardSmallImageFile=art\small-100.png,art\small-125.png,art\small-150.png,art\small-175.png,art\small-200.png,art\small-250.png

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"
Name: "he"; MessagesFile: "compiler:Languages\Hebrew.isl"

[Messages]
en.WelcomeLabel2=This will install [name/ver]: the real VLC 4 engine with the interface designed by Juxtopposed.%n%nIt is an unofficial build, not made or endorsed by VideoLAN, and installs next to an official VLC without touching it.
he.WelcomeLabel2=אשף זה יתקין את [name/ver]: מנוע VLC 4 האמיתי עם הממשק שעיצבה Juxtopposed.%n%nזוהי גרסה לא רשמית, שאינה של VideoLAN, והיא מותקנת לצד VLC רשמי בלי לגעת בו.
en.FinishedLabel=[name] is installed. Enjoy!%n%nThe interface was designed by Juxtopposed: youtube.com/@juxtopposed
he.FinishedLabel=[name] הותקן. צפייה מהנה!%n%nאת הממשק עיצבה Juxtopposed:%nyoutube.com/@juxtopposed

[CustomMessages]
en.DesktopIcon=Create a desktop shortcut
he.DesktopIcon=יצירת קיצור דרך בשולחן העבודה
en.OpenWith=Add {#AppName} to "Open with" for video and audio files (your default player stays the same)
he.OpenWith=הוספת {#AppName} לתפריט "פתח באמצעות" של קובצי וידאו ושמע (נגן ברירת המחדל לא משתנה)
en.Launch=Open {#AppName}
he.Launch=פתיחת {#AppName}
en.Running={#AppName} is open. Setup will close it now and open it again when it's done.
he.Running={#AppName} פתוח. ההתקנה תסגור אותו עכשיו ותפתח אותו מחדש בסיום.
en.StillRunning={#AppName} didn't close. Close it and click Retry.
he.StillRunning={#AppName} לא נסגר. סגור אותו ולחץ על "נסה שוב".
en.RemoveData=Also delete your {#AppName} settings, library and history?
he.RemoveData=למחוק גם את ההגדרות, הספרייה וההיסטוריה של {#AppName}?
en.Optimising=Preparing {#AppName} for a fast start...
he.Optimising=מכין את {#AppName} להפעלה מהירה...
en.ShortcutComment=VLC media player with the interface designed by Juxtopposed
he.ShortcutComment=נגן VLC עם הממשק שעיצבה Juxtopposed

[Tasks]
Name: "desktopicon"; Description: "{cm:DesktopIcon}"; Flags: unchecked
Name: "openwith"; Description: "{cm:OpenWith}"; Flags: unchecked

[Files]
; portable\ holds the user's settings and library: never shipped, never replaced
Source: "{#SourceDir}\*"; DestDir: "{app}"; Excludes: "\portable\*,*.old-*"; Flags: recursesubdirs createallsubdirs ignoreversion

[Dirs]
; Its presence keeps VLC's data next to vlc.exe instead of %APPDATA%\vlc,
; which an installed official VLC uses
Name: "{app}\portable"; Flags: uninsneveruninstall; Check: not IsAdminInstallMode
; Installed for all users (Program Files): its users must be able to write
; their settings there
Name: "{app}\portable"; Flags: uninsneveruninstall; Permissions: users-modify; Check: IsAdminInstallMode

[InstallDelete]
; Plugins of a previous version that this one no longer has
Type: filesandordirs; Name: "{app}\plugins"
Type: files; Name: "{app}\plugins.dat"

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\vlc.exe"; Comment: "{cm:ShortcutComment}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\vlc.exe"; Comment: "{cm:ShortcutComment}"; Tasks: desktopicon

[Registry]
Root: HKA; Subkey: "Software\Classes\VLCRedesign.Media"; ValueType: string; ValueData: "Media file"; Flags: uninsdeletekey; Tasks: openwith
Root: HKA; Subkey: "Software\Classes\VLCRedesign.Media"; ValueType: string; ValueName: "FriendlyTypeName"; ValueData: "Media file ({#AppName})"; Tasks: openwith
Root: HKA; Subkey: "Software\Classes\VLCRedesign.Media\DefaultIcon"; ValueType: string; ValueData: "{app}\vlc.exe,0"; Tasks: openwith
Root: HKA; Subkey: "Software\Classes\VLCRedesign.Media\shell\open"; ValueType: string; ValueName: "FriendlyAppName"; ValueData: "{#AppName}"; Tasks: openwith
Root: HKA; Subkey: "Software\Classes\VLCRedesign.Media\shell\open\command"; ValueType: string; ValueData: """{app}\vlc.exe"" --started-from-file ""%1"""; Tasks: openwith
#define Ext(E) 'Root: HKA; Subkey: "Software\Classes\.' + E + '\OpenWithProgids"; ValueType: string; ValueName: "VLCRedesign.Media"; ValueData: ""; Flags: uninsdeletevalue; Tasks: openwith'
#emit Ext("mp4")
#emit Ext("m4v")
#emit Ext("mkv")
#emit Ext("webm")
#emit Ext("avi")
#emit Ext("mov")
#emit Ext("wmv")
#emit Ext("flv")
#emit Ext("ts")
#emit Ext("m2ts")
#emit Ext("mpg")
#emit Ext("mpeg")
#emit Ext("3gp")
#emit Ext("ogv")
#emit Ext("mp3")
#emit Ext("m4a")
#emit Ext("aac")
#emit Ext("flac")
#emit Ext("wav")
#emit Ext("ogg")
#emit Ext("opus")
#emit Ext("wma")
#emit Ext("m3u")
#emit Ext("m3u8")
#emit Ext("xspf")

[Run]
; A fresh plugin cache for these files: VLC then starts without scanning
Filename: "{app}\vlc-cache-gen.exe"; Parameters: """{app}\plugins"""; Flags: runhidden waituntilterminated; StatusMsg: "{cm:Optimising}"
; Reopen VLC as it was (update or running instance), or offer to open it
Filename: "{app}\vlc.exe"; Parameters: "{code:RelaunchArgs}"; Flags: nowait; Check: ShouldRelaunch
Filename: "{app}\vlc.exe"; Description: "{cm:Launch}"; Flags: nowait postinstall skipifsilent; Check: not ShouldRelaunch

[Code]
var
  WasRunning: Boolean;
  RunningArgs: String;

function AppExe(): String;
begin
  Result := ExpandConstant('{app}\vlc.exe');
end;

{ Process ids (as taskkill arguments) and command line of the VLC Redesign
  instances started from the install folder; other VLCs are left alone. }
function FindRunning(var Pids: String; var CmdLine: String): Boolean;
var
  Locator, Service, Procs, Proc: Variant;
  I: Integer;
begin
  Result := False;
  Pids := '';
  CmdLine := '';
  try
    Locator := CreateOleObject('WbemScripting.SWbemLocator');
    Service := Locator.ConnectServer('.', 'root\CIMV2');
    Procs := Service.ExecQuery('SELECT ProcessId, ExecutablePath, CommandLine FROM Win32_Process WHERE Name = ''vlc.exe''');
    for I := 0 to Procs.Count - 1 do
    begin
      Proc := Procs.ItemIndex(I);
      if (not VarIsNull(Proc.ExecutablePath)) and (CompareText(Proc.ExecutablePath, AppExe()) = 0) then
      begin
        Result := True;
        Pids := Pids + ' /PID ' + IntToStr(Proc.ProcessId);
        if not VarIsNull(Proc.CommandLine) then
          CmdLine := Proc.CommandLine;
      end;
    end;
  except
    Log('Cannot list processes: ' + GetExceptionMessage);
  end;
end;

{ The arguments of a command line, without the program }
function ArgsOf(CmdLine: String): String;
var
  P: Integer;
begin
  CmdLine := Trim(CmdLine);
  if Copy(CmdLine, 1, 1) = '"' then
  begin
    Delete(CmdLine, 1, 1);
    P := Pos('"', CmdLine);
  end
  else
    P := Pos(' ', CmdLine);
  if P = 0 then
    Result := ''
  else
    Result := Trim(Copy(CmdLine, P + 1, Length(CmdLine)));
end;

function IsUpdate(): Boolean;
begin
  Result := ExpandConstant('{param:UPDATE|0}') <> '0';
end;

function ShouldRelaunch(): Boolean;
begin
  Result := WasRunning or (ExpandConstant('{param:RESUME|}') <> '');
end;

function RelaunchArgs(Param: String): String;
var
  Media, Time: String;
begin
  Media := ExpandConstant('{param:RESUME|}');
  Time := ExpandConstant('{param:TIME|}');
  if Media <> '' then
  begin
    Result := '"' + Media + '"';
    if Time <> '' then
      Result := Result + ' :start-time=' + Time;
  end
  else
    Result := RunningArgs;
end;

function CloseRunning(): Boolean;
var
  Pids, CmdLine: String;
  Code, I: Integer;
begin
  Result := True;
  if not FindRunning(Pids, CmdLine) then
    Exit;
  WasRunning := True;
  RunningArgs := ArgsOf(CmdLine);
  if (not WizardSilent) and (not IsUpdate()) then
    MsgBox(CustomMessage('Running'), mbInformation, MB_OK);
  { Ask politely (WM_CLOSE) so VLC saves its settings and position }
  Exec(ExpandConstant('{sys}\taskkill.exe'), Trim(Pids), '', SW_HIDE, ewWaitUntilTerminated, Code);
  for I := 1 to 30 do
  begin
    Sleep(500);
    if not FindRunning(Pids, CmdLine) then
      Exit;
  end;
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/F ' + Trim(Pids), '', SW_HIDE, ewWaitUntilTerminated, Code);
  Sleep(1000);
  Result := not FindRunning(Pids, CmdLine);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  if CloseRunning() then
    Result := ''
  else
    Result := CustomMessage('StillRunning');
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Pids, CmdLine: String;
  Code: Integer;
begin
  if CurUninstallStep = usUninstall then
  begin
    if FindRunning(Pids, CmdLine) then
    begin
      Exec(ExpandConstant('{sys}\taskkill.exe'), Trim(Pids), '', SW_HIDE, ewWaitUntilTerminated, Code);
      Sleep(3000);
      if FindRunning(Pids, CmdLine) then
        Exec(ExpandConstant('{sys}\taskkill.exe'), '/F ' + Trim(Pids), '', SW_HIDE, ewWaitUntilTerminated, Code);
    end;
  end;
  if CurUninstallStep = usPostUninstall then
  begin
    { A silent uninstall keeps the user's data; otherwise ask, defaulting to keep }
    if DirExists(ExpandConstant('{app}\portable')) and (not UninstallSilent) and
       (MsgBox(CustomMessage('RemoveData'), mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES) then
      DelTree(ExpandConstant('{app}\portable'), True, True, True);
    RemoveDir(ExpandConstant('{app}'));
  end;
end;
