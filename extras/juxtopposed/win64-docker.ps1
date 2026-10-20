# Copyright (C) 2026 VLC authors and VideoLAN
# SPDX-License-Identifier: GPL-2.0-or-later
# Build the redesign for Windows x86_64 in Docker and put a portable
# package in -Out. Objects persist in the "vlc-win64-build" volume, so
# later runs only rebuild what changed. Extra arguments go to build.sh.
param(
    [string]$Out = "$env:USERPROFILE\source\vlc-win64",
    [string]$Cache = "$env:USERPROFILE\source\vlc-cache",
    # Only rebuild what changed in an already configured tree
    [switch]$Quick,
    # Only run qmllint on the QML files changed in the working tree
    [switch]$Lint,
    # Docker volume holding the build tree; use another one for a release
    # build so the debug tree stays configured
    [string]$Volume = 'vlc-win64-build',
    # Strip debug information from the packaged binaries
    [switch]$Strip,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$BuildArgs
)
# Native tools report progress on stderr; failures are checked by exit code.
$ErrorActionPreference = 'Continue'
$root = (Resolve-Path "$PSScriptRoot\..\..").Path
$image = 'vlc-win64-redesign:20260611225331'

cmd /c "docker image inspect $image >nul 2>&1"
if ($LASTEXITCODE -ne 0) {
    docker build -t $image -f "$PSScriptRoot\win64.Dockerfile" $PSScriptRoot
    if ($LASTEXITCODE -ne 0) { throw 'docker build failed' }
}

if ($Lint) {
    $qml = @(git -C $root diff --name-only HEAD) + @(git -C $root ls-files --others --exclude-standard) |
        Where-Object { $_ -like '*.qml' } | Sort-Object -Unique
    if (-not $qml) { Write-Host 'No changed QML file'; return }
    docker run --rm -v "${root}:/src:ro" -v "${Volume}:/build:ro" $image `
        sh /src/extras/juxtopposed/qmllint-docker.sh @qml
    return
}

# Same paths as extras/ci/get-contrib-sha.sh win64
$sha = git -C $root rev-list -1 HEAD -- extras/tools contrib extras/ci extras/package/win32
$archive = "vlc-contrib-x86_64-w64-mingw32-$sha.tar.zst"
if (-not (Test-Path "$Cache\$archive")) {
    New-Item -ItemType Directory -Force $Cache | Out-Null
    curl.exe -fL --retry 3 -o "$Cache\$archive" "https://artifacts.videolan.org/vlc/win64/$archive"
    if ($LASTEXITCODE -ne 0) { throw "Prebuilt contrib $archive is not available" }
}
New-Item -ItemType Directory -Force $Out | Out-Null
# A running VLC locks its DLLs and the package copy would fail at the end.
$outPath = (Resolve-Path $Out).Path
$procs = @(Get-Process vlc -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$outPath\*" })
$running = @($procs | Where-Object { -not $_.HasExited })
if ($running) { throw "Close VLC running from $outPath first (pid $($running.Id -join ', '))" }
# A crashed VLC can stay half terminated with its DLLs mapped. Mapped files
# cannot be replaced but can be renamed: move them aside (rsync skips *.old-*)
# and delete the ones moved aside earlier once nothing maps them anymore.
function Test-Locked([string]$path) {
    try { [System.IO.File]::Open($path, 'Open', 'ReadWrite', 'None').Dispose(); return $false }
    catch { return $true }
}
Get-ChildItem $outPath -Recurse -File -Filter '*.old-*' -ErrorAction SilentlyContinue |
    ForEach-Object { Remove-Item -LiteralPath $_.FullName -ErrorAction SilentlyContinue }
$stamp = Get-Date -Format 'yyyyMMddHHmmss'
foreach ($p in $procs) {
    $modules = @(tasklist /m /fi "PID eq $($p.Id)" /fo csv | ConvertFrom-Csv |
        ForEach-Object { $_.Modules -split ',' }) + (Split-Path $p.Path -Leaf)
    Get-ChildItem $outPath -Recurse -File -Include $modules -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike '*.old-*' -and (Test-Locked $_.FullName) } |
        ForEach-Object { Rename-Item -LiteralPath $_.FullName -NewName "$($_.Name).old-$stamp" }
}

# The volume starts root-owned; hand it to the image's user once.
docker run --rm -u root -v "${Volume}:/build" $image chown videolan:videolan /build
if ($LASTEXITCODE -ne 0) { throw 'Cannot prepare the build volume' }
docker run --rm `
    -e CONTRIB_ARCHIVE="/cache/$archive" -e QUICK=$(if ($Quick) { 1 } else { 0 }) -e STRIP=$(if ($Strip) { 1 } else { 0 }) `
    -v "${root}:/src:ro" -v "${Cache}:/cache:ro" -v "${Out}:/out" `
    -v "${Volume}:/build" `
    $image sh -c 'cp /src/extras/juxtopposed/win64-docker.sh /tmp/build.sh && exec sh /tmp/build.sh $@' `
    win64-docker.sh @BuildArgs
if ($LASTEXITCODE -ne 0) { throw "Windows build failed ($LASTEXITCODE)" }
# Without plugins.dat every start scans all plugins, which takes seconds.
& "$Out\vlc-cache-gen.exe" "$Out\plugins"
if ($LASTEXITCODE -ne 0) { Write-Warning "vlc-cache-gen failed ($LASTEXITCODE)" }
Write-Host "Run: $Out\vlc.exe"
