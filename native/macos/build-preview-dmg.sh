#!/usr/bin/env bash
# Disposable macOS CI only: unsigned read-only developer preview disk image.
# Never signs, notarizes, publishes, installs, or modifies /Applications.
set -euo pipefail

if [[ "$(uname -s)" != Darwin || "$#" -ne 2 ||
      "$1" != /* || "$2" != /* ||
      -z "${RUNNER_TEMP:-}" || ! -d "$RUNNER_TEMP" ]]; then
  echo "usage (disposable macOS CI): build-preview-dmg.sh /absolute/Preview.app /absolute/new/Preview.dmg" >&2
  exit 2
fi
if [[ "$(id -u)" -eq 0 ]]; then
  echo 'refusing privileged macOS preview packaging' >&2
  exit 3
fi
app="$1"
image="$2"
# Never write into a real user's Application folder; all writes confined
# to an ephemeral GitHub-hosted runner temp root.
case "$app" in "$RUNNER_TEMP"/*) ;; *) echo 'app outside runner temp refused' >&2; exit 3 ;; esac
case "$image" in "$RUNNER_TEMP"/*) ;; *) echo 'image outside runner temp refused' >&2; exit 3 ;; esac
if [[ ! -d "$app" || -L "$app" || ! -x "$app/Contents/MacOS/tbme-macos-status" ||
      ! -f "$app/Contents/Info.plist" || -L "$app/Contents/Info.plist" ]]; then
  echo 'invalid preview bundle' >&2
  exit 3
fi
if [[ -e "$image" || -L "$image" ]]; then
  echo 'refusing to overwrite existing image, including a symlink' >&2
  exit 3
fi
if [[ "$(plutil -extract CFBundleShortVersionString raw -o - "$app/Contents/Info.plist")" != "0.1.0" ||
      "$(plutil -extract CFBundleIdentifier raw -o - "$app/Contents/Info.plist")" != \
      "com.god13emad.taskbarmonitorenhanced.nativepreview" ]]; then
  echo 'unexpected preview version or bundle identity' >&2
  exit 3
fi
expected_sha="$(shasum -a 256 "$app/Contents/MacOS/tbme-macos-status" | cut -d' ' -f1)"
stage="$(mktemp -d "$RUNNER_TEMP/tbme-preview-dmg.XXXXXXXX")"
case "$stage" in "$RUNNER_TEMP"/tbme-preview-dmg.*) ;; *) echo 'unsafe staging root' >&2; exit 3 ;; esac
mount="$stage/mounted"
source="$stage/source"
mkdir -m 700 -- "$source" "$mount"
attached=false
cleanup() {
  if [[ "$attached" == true ]]; then
    # Refuse to recursively delete a mounted volume on detach failure.
    if ! hdiutil detach -quiet "$mount"; then
      echo 'owned preview image detach failed; staging retained' >&2
      return 1
    fi
    attached=false
  fi
  rm -rf -- "$stage"
}
trap cleanup EXIT

ditto "$app" "$source/TaskbarMonitorEnhancedNativePreview.app"
ln -s /Applications "$source/Applications"
test "$(readlink "$source/Applications")" = '/Applications'
test "$(shasum -a 256 "$source/TaskbarMonitorEnhancedNativePreview.app/Contents/MacOS/tbme-macos-status" | cut -d' ' -f1)" = "$expected_sha"
# Apple recommends UDZO for read-only distributable disk images; this
# *unsigned lab image* is not fit for release and lacks a notarization ticket.
hdiutil create -quiet -format UDZO \
  -volname 'TaskbarMonitorEnhanced Native Preview LAB' \
  -srcfolder "$source" -o "$image"
test -f "$image" && test -s "$image" && test ! -L "$image"
hdiutil verify -quiet "$image"
hdiutil attach -quiet -readonly -nobrowse -noautoopen \
  -mountpoint "$mount" "$image"
attached=true
mounted_app="$mount/TaskbarMonitorEnhancedNativePreview.app"
test -x "$mounted_app/Contents/MacOS/tbme-macos-status"
test "$(readlink "$mount/Applications")" = '/Applications'
test "$(plutil -extract CFBundleIdentifier raw -o - "$mounted_app/Contents/Info.plist")" = \
  'com.god13emad.taskbarmonitorenhanced.nativepreview'
mounted_sha="$(shasum -a 256 "$mounted_app/Contents/MacOS/tbme-macos-status" | cut -d' ' -f1)"
test "$mounted_sha" = "$expected_sha"
"$mounted_app/Contents/MacOS/tbme-macos-status" --self-test |
  grep -Fx 'TBME_MACOS_APPKIT_NATIVE_SENSOR_SELFTEST=PASS'
# A read-only attach must disallow creating a file in the mounted volume.
if ( : > "$mount/R457_SHOULD_NEVER_BE_CREATED" ) 2>/dev/null; then
  echo 'mounted image unexpectedly writable' >&2
  exit 4
fi
test ! -e "$mount/R457_SHOULD_NEVER_BE_CREATED"
hdiutil detach -quiet "$mount"
attached=false
hdiutil verify -quiet "$image"
echo 'TBME_R457_MACOS_UNSIGNED_UDZO_DMG_MOUNT_READONLY_HASH_ROUNDTRIP=PASS_LAB_ONLY'
