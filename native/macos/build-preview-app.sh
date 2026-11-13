#!/usr/bin/env bash
# Build an unsigned local-only AppKit app bundle for an isolated preview.
set -euo pipefail
if [[ "$(uname -s)" != Darwin || "$#" -ne 1 || "$1" != /* ]]; then
  echo "usage (macOS): bash native/macos/build-preview-app.sh /absolute/new/path/Preview.app" >&2
  exit 2
fi
app="$1"
if [[ -e "$app" || -L "$app" ]]; then
  echo "refusing to overwrite existing native app candidate" >&2
  exit 3
fi
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
mkdir -p -- "$app/Contents/MacOS"
clang++ -std=c++17 -O2 -fobjc-arc -Wall -Wextra -Werror -pedantic   "$root/native/macos/StatusBar.mm" -framework AppKit -framework Foundation   -o "$app/Contents/MacOS/tbme-macos-status"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>tbme-macos-status</string>
  <key>CFBundleIdentifier</key><string>com.god13emad.taskbarmonitorenhanced.nativepreview</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>TaskbarMonitorEnhanced Native Preview</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
plutil -lint "$app/Contents/Info.plist"
"$app/Contents/MacOS/tbme-macos-status" --self-test
echo "TBME_MACOS_UNSIGNED_PREVIEW_BUNDLE=PASS"
