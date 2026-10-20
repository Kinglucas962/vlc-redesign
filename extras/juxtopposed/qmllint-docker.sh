#!/bin/sh
# Copyright (C) 2026 VLC authors and VideoLAN
# SPDX-License-Identifier: GPL-2.0-or-later
# Lint QML files of the Qt interface without building, inside the image of
# win64-docker.sh (see win64-docker.ps1 -Lint). Needs a configured /build tree
# for the generated qmldir and res.qrc files; reads the sources from /src.
#   qmllint-docker.sh modules/gui/qt/player/qml/TopBar.qml ...
set -eu
qt=/build/vlc/win64/modules/gui/qt
tree=/tmp/qmllint
rm -rf "$tree"

# Rebuild the VLC.* module layout (VLC/Player/qmldir + files) from res.qrc
for qrc in "$qt"/*/res.qrc; do
    dir=$(dirname "$qrc")
    prefix=$(sed -n 's|.*<qresource prefix="/qt/qml/\([^"]*\)">.*|\1|p' "$qrc")
    [ -n "$prefix" ] || continue
    mkdir -p "$tree/$prefix"
    grep -v '^prefer ' "$dir/qmldir" > "$tree/$prefix/qmldir"
    sed -n 's|.*<file alias="\([^"]*\)">/build/vlc/\([^<]*\)</file>.*|\1 \2|p' "$qrc" |
        while read -r alias source; do
            mkdir -p "$(dirname "$tree/$prefix/$alias")"
            ln -sf "/src/$source" "$tree/$prefix/$alias"
        done
done

status=0
for file in "$@"; do
    # Lint the copy inside its module, so same-module types resolve
    linked=$(find "$tree" -lname "/src/$file" | head -n 1)
    if [ -z "$linked" ]; then
        # New file: put it in the module of the other files of its directory
        sibling=$(find "$tree" -lname "/src/$(dirname "$file")/*" | head -n 1)
        if [ -z "$sibling" ]; then
            echo "$file: not part of any QML module" >&2
            status=1
            continue
        fi
        linked="$(dirname "$sibling")/$(basename "$file")"
        ln -sf "/src/$file" "$linked"
        echo "$(basename "$file") 1.0 $(basename "$file")" >> "$(dirname "$sibling")/qmldir"
    fi
    /opt/tools/bin/qmllint -I "$tree" -I /build/vlc/contrib/x86_64-w64-mingw32/qml \
        --unqualified disable --import disable --missing-property disable \
        --unresolved-type disable --unresolved-alias disable \
        "$linked" 2>&1 | sed "s|$linked|$file|g" |
        grep -E '^(Warning|Error):' |
        grep -vE 'unused-imports|signal-handler-parameters|missing-type' || true
done
exit $status
