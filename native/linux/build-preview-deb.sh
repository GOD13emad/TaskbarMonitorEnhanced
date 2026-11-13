#!/usr/bin/env bash
# Build a disposable unsigned Debian preview package; never install it here.
set -euo pipefail
if [[ "$(uname -s)" != Linux || "$#" -ne 1 || "$1" != /* ]]; then
  echo "usage (Linux): bash native/linux/build-preview-deb.sh /absolute/new/path/preview.deb" >&2
  exit 2
fi
destination="$1"
if [[ -e "$destination" || -L "$destination" ]]; then
  echo "refusing to overwrite existing native preview package" >&2
  exit 3
fi
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
stage="$(mktemp -d)"
trap 'rm -rf -- "$stage"' EXIT
mkdir -p -- "$stage/root/DEBIAN" "$stage/root/usr/bin" "$stage/root/usr/share/applications"
c++ -std=c++17 -O2 -march=x86-64 -mtune=generic -Wl,-z,x86-64-baseline -Wall -Wextra -Werror -pedantic   "$root/native/linux/Panel.cpp" -o "$stage/root/usr/bin/tbme-linux-panel"   $(pkg-config --cflags --libs gtk+-3.0)
# R458: reject binaries requiring AVX2/x86-64-v3 at build time.
# Never strip GNU ELF notes to silence a real loader compatibility check.
isa_notes="$(readelf -n "$stage/root/usr/bin/tbme-linux-panel")"
printf "%s\n" "$isa_notes"
if ! grep -Eq 'x86 ISA needed: x86-64-baseline[[:space:]]*$' <<<"$isa_notes"; then
  printf '%s\n' "$isa_notes" >&2
  echo 'R458 refusing Linux preview requiring above x86-64-baseline' >&2
  exit 5
fi
chmod 0755 "$stage/root/usr/bin/tbme-linux-panel"
cat > "$stage/root/usr/share/applications/tbme-native-preview.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Version=1.0
Name=TaskbarMonitorEnhanced Native Preview
Comment=Read-only CPU and RAM panel (experimental)
Exec=/usr/bin/tbme-linux-panel
Icon=utilities-system-monitor
Terminal=false
Categories=System;Monitor;
DESKTOP
cat > "$stage/root/DEBIAN/control" <<CONTROL
Package: taskbarmonitorenhanced-native-preview
Version: 0.1.0~r443
Section: utils
Priority: optional
Architecture: $(dpkg --print-architecture)
Maintainer: TaskbarMonitorEnhanced contributors
Depends: libgtk-3-0t64 | libgtk-3-0, libc6, libstdc++6
Description: Experimental TaskbarMonitorEnhanced native GTK3 CPU/RAM panel
 Read-only GTK3 desktop window using platform-native system CPU/RAM metrics.
 This unsigned preview is not the Windows 1.7.10 release.
CONTROL
dpkg-deb --build --root-owner-group "$stage/root" "$destination"
if [[ "$(dpkg-deb --field "$destination" Package)" != "taskbarmonitorenhanced-native-preview" ]]; then
  echo 'preview package metadata mismatch' >&2
  exit 4
fi
dpkg-deb --contents "$destination" | grep -F '/usr/bin/tbme-linux-panel'
dpkg-deb --contents "$destination" | grep -F '/usr/share/applications/tbme-native-preview.desktop'
echo 'TBME_LINUX_UNSIGNED_DEBIAN_PREVIEW=PASS_NO_INSTALL'
