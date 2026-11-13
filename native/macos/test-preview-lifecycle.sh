#!/usr/bin/env bash
# macOS unsigned preview: disposable, non-root, simulated bundle lifecycle.
# This is NOT a production installer, codesign, or notarization acceptance.
set -euo pipefail
if [[ "$(uname -s)" != Darwin || "$#" -ne 1 || "$1" != /* ||
      -z "${RUNNER_TEMP:-}" || ! -d "$RUNNER_TEMP" ]]; then
  echo "usage (macOS disposable CI only): bash native/macos/test-preview-lifecycle.sh /absolute/Preview.app" >&2
  exit 2
fi
if [[ "$(id -u)" == 0 ]]; then
  echo 'refusing privileged native preview lifecycle' >&2
  exit 3
fi
bundle="$1"
test -d "$bundle" && test ! -L "$bundle"
test -x "$bundle/Contents/MacOS/tbme-macos-status"
plist="$bundle/Contents/Info.plist"
test -f "$plist" && test ! -L "$plist"
test "$(plutil -extract CFBundleShortVersionString raw -o - "$plist")" = '0.1.0'
test "$(plutil -extract CFBundleIdentifier raw -o - "$plist")" = \
  'com.god13emad.taskbarmonitorenhanced.nativepreview'
sha="$(shasum -a 256 "$bundle/Contents/MacOS/tbme-macos-status" | cut -d' ' -f1)"
stage="$(mktemp -d "$RUNNER_TEMP/tbme-macos-lifecycle.XXXXXXXX")"
test -d "$stage" && test ! -L "$stage"
cleanup() {
  # Only the exact new temporary directory is owned by this fixture.
  case "$stage" in "$RUNNER_TEMP"/tbme-macos-lifecycle.*) rm -rf -- "$stage" ;; esac
}
trap cleanup EXIT

apps="$stage/disposable-user-Applications"
mkdir -m 700 -- "$apps"
installed="$apps/TaskbarMonitorEnhancedNativePreview.app"
next="$apps/.TaskbarMonitorEnhancedNativePreview.next.app"
previous="$apps/.TaskbarMonitorEnhancedNativePreview.previous.app"
reinstalled="$apps/.TaskbarMonitorEnhancedNativePreview.before-reinstall.app"
retired="$apps/.TaskbarMonitorEnhancedNativePreview.retired.app"
removed="$apps/.TaskbarMonitorEnhancedNativePreview.removed.app"
test ! -e "$installed"
ditto "$bundle" "$installed"
oldplist="$installed/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string 0.0.1 "$oldplist"
plutil -replace CFBundleVersion -string 0.0.1 "$oldplist"
plutil -lint "$oldplist"
test "$(plutil -extract CFBundleShortVersionString raw -o - "$oldplist")" = 0.0.1
test "$(shasum -a 256 "$installed/Contents/MacOS/tbme-macos-status" | cut -d' ' -f1)" = "$sha"

# NSUserDefaults are outside the bundle: explicit preview user preference.
test "$("$installed/Contents/MacOS/tbme-macos-status" --set-interval 5)" = 'refreshSeconds=5'
test "$("$installed/Contents/MacOS/tbme-macos-status" --settings)" = 'refreshSeconds=5'
prepare_next() {
  # Refuse an occupied path including dangling symlinks. Never overwrite.
  if [[ -e "$next" || -L "$next" ]]; then return 3; fi
  ditto "$bundle" "$next"
  test ! -L "$next"
  test "$(shasum -a 256 "$next/Contents/MacOS/tbme-macos-status" | cut -d' ' -f1)" = "$sha"
  test "$(plutil -extract CFBundleShortVersionString raw -o - "$next/Contents/Info.plist")" = '0.1.0'
}
ln -s "$stage/forbidden-nonexistent-target" "$next"
if prepare_next >/dev/null 2>&1; then
  echo 'occupied symlink next path incorrectly accepted' >&2
  exit 4
fi
test ! -e "$stage/forbidden-nonexistent-target"
unlink "$next"
test "$(plutil -extract CFBundleShortVersionString raw -o - "$oldplist")" = '0.0.1'
echo 'TBME_R454_MACOS_PREVIEW_NO_CLOBBER_SYMLINK_AND_OLD_BUNDLE_PRESERVED=PASS'

# Upgrade from synthetic predecessor with a separate rollback copy.
prepare_next
test ! -e "$previous"
mv "$installed" "$previous"
mv "$next" "$installed"
test "$(plutil -extract CFBundleShortVersionString raw -o - "$installed/Contents/Info.plist")" = '0.1.0'
test "$(plutil -extract CFBundleShortVersionString raw -o - "$previous/Contents/Info.plist")" = '0.0.1'
test "$("$installed/Contents/MacOS/tbme-macos-status" --settings)" = 'refreshSeconds=5'
echo 'TBME_R454_MACOS_SYNTHETIC_INPLACE_UPGRADE_AND_PREFERENCES=PASS'

# Same-version reinstall without deleting the independently kept predecessor.
prepare_next
test ! -e "$reinstalled"
mv "$installed" "$reinstalled"
mv "$next" "$installed"
test "$(shasum -a 256 "$installed/Contents/MacOS/tbme-macos-status" | cut -d' ' -f1)" = "$sha"
test "$("$installed/Contents/MacOS/tbme-macos-status" --settings)" = 'refreshSeconds=5'
echo 'TBME_R454_MACOS_SAME_VERSION_REINSTALL_PRESERVES_PREFERENCES=PASS'

# Rollback to the explicitly synthetic previous bundle.
test ! -e "$retired"
mv "$installed" "$retired"
mv "$previous" "$installed"
test "$(plutil -extract CFBundleShortVersionString raw -o - "$installed/Contents/Info.plist")" = '0.0.1'
test "$("$installed/Contents/MacOS/tbme-macos-status" --settings)" = 'refreshSeconds=5'
echo 'TBME_R454_MACOS_SYNTHETIC_PREDECESSOR_ROLLBACK=PASS'

# Remove just this disposable staged bundle, leaving user preference intact.
test ! -e "$removed"
mv "$installed" "$removed"
test ! -e "$installed"
test "$("$bundle/Contents/MacOS/tbme-macos-status" --settings)" = 'refreshSeconds=5'
mv "$removed" "$installed"
test "$("$installed/Contents/MacOS/tbme-macos-status" --settings)" = 'refreshSeconds=5'
echo 'TBME_R454_MACOS_PREVIEW_REMOVE_RESTORE_AND_USER_PREFS=PASS'
# The runner may have unrelated macOS preferences; do not erase that domain.
