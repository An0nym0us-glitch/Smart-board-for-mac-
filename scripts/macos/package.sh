#!/usr/bin/env bash
# Builds the macOS disk image (ClassBoard-<version>-macOS-<arch>.dmg) from a configured and
# built CMake tree, then checks that the ClassBoard.app inside is self-contained.
#
#   scripts/macos/package.sh build            # writes build/ClassBoard-*.dmg
#
# CPack installs the bundle, runs macdeployqt (Qt frameworks, plug-ins and, when configured
# with -DCLASSBOARD_PDFTOPPM=..., Poppler's pdftoppm and its libraries) and signs it ad hoc.
set -euo pipefail

build="${1:?usage: $0 <build-dir>}"
build="$(cd "$build" && pwd)"

rm -f "$build"/ClassBoard-*.dmg
(cd "$build" && cpack -G DragNDrop)
dmg="$(ls "$build"/ClassBoard-*.dmg)"
echo "Built $dmg ($(du -h "$dmg" | cut -f1))"

# Check the bundle that went into the image.
mnt="$(mktemp -d)"
hdiutil attach -nobrowse -readonly -mountpoint "$mnt" "$dmg" > /dev/null
trap 'hdiutil detach "$mnt" > /dev/null || true' EXIT
app="$mnt/ClassBoard.app"
test -x "$app/Contents/MacOS/ClassBoard"
test -f "$app/Contents/Resources/classboard.icns"
test -L "$mnt/Applications"
plutil -lint "$app/Contents/Info.plist"
echo "Version: $(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")," \
     "minimum macOS: $(/usr/libexec/PlistBuddy -c 'Print LSMinimumSystemVersion' "$app/Contents/Info.plist")"

# Every library a binary in the bundle loads must be in the bundle or part of macOS.
app_real="$(cd "$app" && pwd -P)"
bad=0
while IFS= read -r -d '' f; do
    if file -b "$f" | grep -q 'Mach-O'; then
        # A library's own install name (LC_ID_DYLIB) is listed too; it is not loaded.
        id="$(otool -D "$f" | tail -n +2)"
        while read -r dep; do
            if [ -n "$id" ] && [ "$dep" = "$id" ]; then
                continue
            fi
            case "$dep" in
                @executable_path/*|@loader_path/*)
                    # Relative references must end up at a file inside the bundle.
                    if [ "${dep#@executable_path/}" != "$dep" ]; then
                        target="$app/Contents/MacOS/${dep#@executable_path/}"
                    else
                        target="$(dirname "$f")/${dep#@loader_path/}"
                    fi
                    real="$(cd "$(dirname "$target")" 2> /dev/null && pwd -P)/$(basename "$target")"
                    case "$real" in
                        "$app_real"/*) [ -e "$real" ] || { echo "::error::$f loads $dep, which is missing ($real)"; bad=1; } ;;
                        *) echo "::error::$f loads $dep, which resolves outside the bundle ($real)"; bad=1 ;;
                    esac ;;
                @rpath/*)
                    # Search paths only ever point into Contents/Frameworks (checked below).
                    [ -e "$app/Contents/Frameworks/${dep#@rpath/}" ] \
                        || { echo "::error::$f loads $dep, which is not in Contents/Frameworks"; bad=1; } ;;
                /usr/lib/*|/System/*) ;;
                *) echo "::error::$f loads $dep from outside the bundle"; bad=1 ;;
            esac
        done < <(otool -L "$f" | tail -n +2 | awk '{print $1}')
        while read -r rpath; do
            case "$rpath" in
                @executable_path/*|@loader_path/*) ;;
                *) echo "::error::$f searches libraries in $rpath (outside the bundle)"; bad=1 ;;
            esac
        done < <(otool -l "$f" | awk '/cmd LC_RPATH/ {getline; getline; print $2}')
    fi
done < <(find "$app/Contents" -type f -print0)
if ! otool -l "$app/Contents/MacOS/ClassBoard" | grep -q 'path @executable_path/../Frameworks '; then
    echo "::error::ClassBoard does not search Contents/Frameworks for its @rpath libraries"
    bad=1
fi
if [ "$bad" -ne 0 ]; then
    exit 1
fi
broken="$(find "$app" -type l ! -exec test -e {} \; -print)"
if [ -n "$broken" ]; then
    echo "::error::Broken links in the bundle:"
    echo "$broken"
    exit 1
fi
codesign --verify --deep --strict --verbose=2 "$app"
echo "Architectures: $(lipo -archs "$app/Contents/MacOS/ClassBoard")"
if [ -x "$app/Contents/MacOS/pdftoppm" ]; then
    "$app/Contents/MacOS/pdftoppm" -v 2>&1 | head -n 1
fi
echo "ClassBoard.app is self-contained"
