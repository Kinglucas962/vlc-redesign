#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 2 ]]; then
    echo "Usage: $0 <portable-package-directory> <evidence-directory>" >&2
    exit 2
fi
package=$(realpath -e "$1")
mkdir -p "$2"
evidence=$(realpath -e "$2")
triplet=x86_64-w64-mingw32
expected_image=registry.videolan.org/vlc-debian-win64-posix@sha256:8e83e800036f8f4a6da1031a6b80c2b5bad8337259c072ffa22398baaeaad880
[[ "${M0_IMAGE:-}" == "$expected_image" ]]
test -s "$package/vlc.exe"
compiler=$(command -v "$triplet-gcc")
objdump=$(command -v "$triplet-objdump")
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT

# Record every existing file, then prove copying runtimes changed none of them.
find "$package" -type f -print0 | sort -z | xargs -0 sha256sum > "$evidence/application-before.sha256"
{
    printf 'image=%s\npackaging_sha=%s\ncompiler_path=%s\n' "$M0_IMAGE" "${M0_PACKAGING_SHA:-unrecorded}" "$compiler"
    "$compiler" --version
} > "$evidence/runtime-provenance.txt"

imports()
{
    "$objdump" -p "$1" | awk '/DLL Name:/ {print tolower($3)}'
}
is_runtime()
{
    case "$1" in
        libgcc_s_seh-1.dll|libwinpthread-1.dll|libstdc++-6.dll|libgomp-1.dll|libssp-0.dll|libquadmath-0.dll|libatomic-1.dll) return 0 ;;
        *) return 1 ;;
    esac
}

while IFS= read -r -d '' binary; do
    imports "$binary" >> "$temporary/imports"
done < <(find "$package" -type f \( -name '*.dll' -o -name '*.exe' \) -print0)
sort -u "$temporary/imports" > "$temporary/pending"
declare -A visited=()
while [[ -s "$temporary/pending" ]]; do
    mapfile -t pending < "$temporary/pending"
    : > "$temporary/pending"
    for name in "${pending[@]}"; do
        is_runtime "$name" || continue
        [[ -z "${visited[$name]:-}" ]] || continue
        visited[$name]=1
        resolved=$("$compiler" -print-file-name="$name")
        [[ "$resolved" == /* && -f "$resolved" ]] || {
            echo "Compiler cannot locate imported runtime $name; refusing another toolchain." >&2
            exit 1
        }
        resolved=$(realpath -e "$resolved")
        case "$resolved" in
            /usr/lib/gcc/$triplet/*/*|/usr/$triplet/*) ;;
            *) echo "Unexpected runtime path: $resolved" >&2; exit 1 ;;
        esac
        "$objdump" -f "$resolved" | grep -q 'pei-x86-64'
        digest=$(sha256sum "$resolved" | cut -d ' ' -f1)
        if [[ -e "$package/$name" ]]; then
            [[ "$(sha256sum "$package/$name" | cut -d ' ' -f1)" == "$digest" ]] || {
                echo "Existing runtime $name differs from the pinned compiler runtime." >&2
                exit 1
            }
        else
            cp -- "$resolved" "$package/$name"
        fi
        printf 'runtime=%s source=%s sha256=%s\n' "$name" "$resolved" "$digest" \
            | tee -a "$evidence/runtime-provenance.txt"
        imports "$resolved" >> "$temporary/pending"
    done
done
sha256sum --check --quiet "$evidence/application-before.sha256"
printf 'existing_application_files_unchanged=true\n' | tee -a "$evidence/runtime-provenance.txt"
find "$package" -maxdepth 1 -type f -name '*.dll' -printf '%f\n' | sort > "$evidence/root-dlls.txt"
