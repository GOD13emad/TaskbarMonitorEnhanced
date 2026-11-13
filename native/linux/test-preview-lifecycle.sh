#!/usr/bin/env bash
# R446 disposable GitHub-hosted runner only. Never execute on owner machines.
# Tests synthetic-previous -> committed-current .deb package mechanics, not a public upgrade.
set -euo pipefail
package='taskbarmonitorenhanced-native-preview'
if [[ "${RUNNER_ENVIRONMENT:-}" != 'github-hosted' ||
      "${RUNNER_OS:-}" != 'Linux' ||
      "${GITHUB_ACTIONS:-}" != 'true' ||
      "${CI:-}" != 'true' ||
      "${RUNNER_TEMP:-}" != /* ||
      "$#" -ne 1 || "$1" != "$RUNNER_TEMP/"* ||
      "$1" != *.deb || ! -f "$1" || -L "$1" ||
      "$(id -u)" -eq 0 ]]; then
  echo 'R446 requires a GitHub-hosted Ubuntu CI runner and a runner-temp .deb' >&2
  exit 2
fi
current="$1"
if dpkg-query -s "$package" 2>/dev/null | grep -q '^Status: install ok installed$'; then
  echo 'R446 refused an already-installed package' >&2
  exit 3
fi
if ! sudo -n true; then
  echo 'R446 runner noninteractive sudo unavailable' >&2
  exit 4
fi
version="$(dpkg-deb --field "$current" Version)"
old_version='0.0.9~r446synthetic'
if [[ "$(dpkg-deb --field "$current" Package)" != "$package" ||
      "$version" != '0.1.0~r443' ]] ||
   ! dpkg --compare-versions "$old_version" lt "$version"; then
  echo 'R446 unexpected candidate identity or ordering' >&2
  exit 5
fi
stage="$(mktemp -d "$RUNNER_TEMP/tbme-native-lifecycle.XXXXXXXX")"
test -d "$stage" && test ! -L "$stage"
installed_by_this_test=false
cleanup() {
  if [[ "$installed_by_this_test" == true ]]; then
    sudo -n dpkg --purge "$package" >/dev/null 2>&1 || true
  fi
  rm -rf -- "$stage"
}
trap cleanup EXIT
dpkg-deb --raw-extract "$current" "$stage/previous-root"
dpkg-deb --extract "$current" "$stage/current-root"
source_binary="$stage/current-root/usr/bin/tbme-linux-panel"
test -x "$source_binary"
source_sha="$(sha256sum "$source_binary" | cut -d' ' -f1)"
control="$stage/previous-root/DEBIAN/control"
test "$(grep -c '^Version: 0.1.0~r443$' "$control")" = 1
sed -i 's/^Version: 0.1.0~r443$/Version: 0.0.9~r446synthetic/' "$control"
cat > "$stage/previous-root/usr/bin/tbme-linux-panel" <<'LEGACY'
#!/bin/sh
if [ "$#" -eq 1 ] && [ "$1" = "--self-test" ]; then
  echo 'TBME_NATIVE_R446_SYNTHETIC_PREDECESSOR=PASS'
  exit 0
fi
exit 2
LEGACY
chmod 0755 "$stage/previous-root/usr/bin/tbme-linux-panel"
dpkg-deb --build --root-owner-group "$stage/previous-root" "$stage/synthetic-previous.deb" >/dev/null
test "$(dpkg-deb --field "$stage/synthetic-previous.deb" Version)" = "$old_version"
installed_by_this_test=true
sudo -n dpkg -i "$stage/synthetic-previous.deb"
test "$(dpkg-query -W -f='${Version}' "$package")" = "$old_version"
/usr/bin/tbme-linux-panel --self-test | grep -Fx 'TBME_NATIVE_R446_SYNTHETIC_PREDECESSOR=PASS'
echo 'TBME_R446_SYNTHETIC_OLD_INSTALL=PASS'

# Pre-existing future native user preferences, never in the runner's real home.
export XDG_CONFIG_HOME="$stage/owned-user-config"
prefs="$XDG_CONFIG_HOME/taskbarmonitorenhanced-native-preview/settings.ini"
mkdir -p "$(dirname "$prefs")"
cat > "$prefs" <<'PREFS'
[NativeTemperatureAlert]
enabled=true
bell=false
thresholdC=93
PREFS
chmod 0600 "$prefs"
original_pref_hash="$(sha256sum "$prefs" | cut -d' ' -f1)"
sudo -n dpkg -i "$current"
test "$(dpkg-query -W -f='${Version}' "$package")" = "$version"
test "$(sha256sum /usr/bin/tbme-linux-panel | cut -d' ' -f1)" = "$source_sha"
/usr/bin/tbme-linux-panel --self-test |
  grep -Fx 'TBME_LINUX_GTK3_NATIVE_SENSOR_SELFTEST=PASS'
if /usr/bin/tbme-linux-panel --unsupported >/dev/null 2>&1; then
  echo 'R446 upgraded package accepted unsupported arguments' >&2
  exit 6
fi
test "$(/usr/bin/tbme-linux-panel --settings)" = 'alert=true bell=false thresholdC=93'
test "$(sha256sum "$prefs" | cut -d' ' -f1)" = "$original_pref_hash"
echo 'TBME_R446_SYNTHETIC_TO_CURRENT_IN_PLACE_UPGRADE=PASS'

sudo -n dpkg -i "$current"
test "$(dpkg-query -W -f='${Version}' "$package")" = "$version"
test "$(sha256sum /usr/bin/tbme-linux-panel | cut -d' ' -f1)" = "$source_sha"
test "$(/usr/bin/tbme-linux-panel --settings)" = 'alert=true bell=false thresholdC=93'
test "$(sha256sum "$prefs" | cut -d' ' -f1)" = "$original_pref_hash"
echo 'TBME_R446_SAME_VERSION_REINSTALL_FUNCTIONAL_IDENTITY=PASS'

# R463: exercise an actual dpkg downgrade to the synthetic predecessor,
# then reapply the candidate. A non-default user edit must survive both.
before_rollback='alert=true bell=false thresholdC=97'
/usr/bin/tbme-linux-panel --set-threshold 97
test "$(/usr/bin/tbme-linux-panel --settings)" = "$before_rollback"
rollback_pref_hash="$(sha256sum "$prefs" | cut -d' ' -f1)"
test "$rollback_pref_hash" != "$original_pref_hash"
sudo -n dpkg -i "$stage/synthetic-previous.deb"
test "$(dpkg-query -W -f='${Status} ${Version}' "$package")" = "install ok installed $old_version"
/usr/bin/tbme-linux-panel --self-test | grep -Fx 'TBME_NATIVE_R446_SYNTHETIC_PREDECESSOR=PASS'
test "$(sha256sum "$prefs" | cut -d' ' -f1)" = "$rollback_pref_hash"
echo 'TBME_R463_DPKG_DOWNGRADE_RESTORES_PREDECESSOR_AND_PRESERVES_USER_EDIT=PASS'

sudo -n dpkg -i "$current"
test "$(dpkg-query -W -f='${Status} ${Version}' "$package")" = "install ok installed $version"
test "$(sha256sum /usr/bin/tbme-linux-panel | cut -d' ' -f1)" = "$source_sha"
/usr/bin/tbme-linux-panel --self-test | grep -Fx 'TBME_LINUX_GTK3_NATIVE_SENSOR_SELFTEST=PASS'
test "$(/usr/bin/tbme-linux-panel --settings)" = "$before_rollback"
test "$(sha256sum "$prefs" | cut -d' ' -f1)" = "$rollback_pref_hash"
test "$(stat -c '%a' "$prefs")" = 600
echo 'TBME_R463_DPKG_REUPGRADE_RESTORES_CANDIDATE_AND_RELOADS_USER_EDIT=PASS'

sudo -n dpkg --remove "$package"
test ! -e /usr/bin/tbme-linux-panel
test ! -e /usr/share/applications/tbme-native-preview.desktop
sudo -n dpkg --purge "$package"
if dpkg-query -s "$package" 2>/dev/null | grep -q '^Status: install ok installed$'; then
  echo 'R446 package remained installed' >&2
  exit 7
fi
installed_by_this_test=false
test -f "$prefs"
test "$(sha256sum "$prefs" | cut -d' ' -f1)" = "$rollback_pref_hash"
echo 'TBME_R446_DISPOSABLE_UPGRADE_REMOVE_PURGE=PASS'
