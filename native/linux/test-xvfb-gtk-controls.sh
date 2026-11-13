#!/usr/bin/env bash
# R462: real XTEST clicks on native GTK controls, confined to disposable CI Xvfb.
# Never use this harness on the owner's actual Linux X11/Wayland desktop.
set -euo pipefail
if [[ "${GITHUB_ACTIONS:-}" != true || "${TBME_DISPOSABLE_XVFB:-}" != 1 ||
      -z "${DISPLAY:-}" || "$#" != 1 ]]; then
  echo 'R462: disposable GitHub Actions Xvfb required' >&2
  exit 2
fi
panel="$(realpath -- "$1")"
test -x "$panel"
root="$(mktemp -d "${RUNNER_TEMP:-/tmp}/tbme-native-clicks.XXXXXXXX")"
pid=''
cleanup() {
  if [[ -n "$pid" ]]; then
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  fi
  rm -rf -- "$root"
}
trap cleanup EXIT
export XDG_CONFIG_HOME="$root/config" GDK_BACKEND=x11 GTK_USE_PORTAL=0
mkdir -m 0700 -- "$XDG_CONFIG_HOME"
setting() { "$panel" --settings; }
require_setting() {
  local expected="$1" current='' i
  for i in {1..25}; do
    current="$(setting)"
    if [[ "$current" == "$expected" ]]; then return 0; fi
    sleep 0.15
  done
  printf 'R462 expected: %s\nR462 actual: %s\n' "$expected" "$current" >&2
  return 1
}
require_setting 'alert=false bell=false thresholdC=85'
"$panel" >"$root/window.log" 2>&1 &
pid=$!
window=''
for i in {1..40}; do
  if ! kill -0 "$pid" 2>/dev/null; then
    cat "$root/window.log" >&2
    echo 'R462 native GTK process exited before click' >&2
    exit 3
  fi
  window="$(xdotool search --onlyvisible --name '^TaskbarMonitorEnhanced Native Linux$' 2>/dev/null | head -n 1 || true)"
  [[ -n "$window" ]] && break
  sleep 0.15
done
if [[ -z "$window" ]]; then
  cat "$root/window.log" >&2
  echo 'R462 GTK top-level not mapped' >&2
  exit 4
fi
xdotool getwindowgeometry --shell "$window"
# The GTK theme may have client-side decorations. Probe the first checkbox
# vertically, but require an observed settings transition; no blind PASS.
warning_y=''
for y in 50 62 74 86 98 110; do
  xdotool mousemove --window "$window" 62 "$y" click --clearmodifiers 1
  sleep 0.15
  if [[ "$(setting)" == 'alert=true bell=false thresholdC=85' ]]; then
    warning_y="$y"
    break
  fi
done
if [[ -z "$warning_y" ]]; then
  echo 'R462 visual checkbox did not respond to native XTEST clicks' >&2
  exit 5
fi
xdotool mousemove --window "$window" 62 "$warning_y" click --clearmodifiers 1
require_setting 'alert=false bell=false thresholdC=85'
echo 'TBME_R462_REAL_XTEST_GTK_VISUAL_WARNING_TOGGLE_BOTH_DIRECTIONS=PASS'
# Never enable alert and bell simultaneously; this fixture must not emit audio.
bell_x=''
for x in 160 185 210 235 260; do
  xdotool mousemove --window "$window" "$x" "$warning_y" click --clearmodifiers 1
  sleep 0.15
  if [[ "$(setting)" == 'alert=false bell=true thresholdC=85' ]]; then
    bell_x="$x"
    break
  fi
done
if [[ -z "$bell_x" ]]; then
  echo 'R462 opt-in bell checkbox did not respond to XTEST clicks' >&2
  exit 6
fi
xdotool mousemove --window "$window" "$bell_x" "$warning_y" click --clearmodifiers 1
require_setting 'alert=false bell=false thresholdC=85'
test "$(stat -c %a "$XDG_CONFIG_HOME/taskbarmonitorenhanced-native-preview/settings.ini")" = 600
echo 'TBME_R462_REAL_XTEST_GTK_BELL_OPTIN_TOGGLE_BOTH_DIRECTIONS=PASS_NO_AUDIO'
echo 'TBME_R462_UI_CONTROLS_ISOLATED_SETTINGS_0600=PASS'
# Scroll one increment on the real GtkSpinButton and back. The probe is
# read-back-driven rather than assuming a particular desktop theme width.
spin_x=''
for x in 450 480 510 540 570 600; do
  xdotool mousemove --window "$window" "$x" "$warning_y" click 4
  sleep 0.15
  if [[ "$(setting)" == 'alert=false bell=false thresholdC=86' ]]; then
    spin_x="$x"
    break
  fi
done
if [[ -z "$spin_x" ]]; then
  echo 'R462 GTK threshold spin did not respond to scroll input' >&2
  exit 7
fi
xdotool mousemove --window "$window" "$spin_x" "$warning_y" click 5
require_setting 'alert=false bell=false thresholdC=85'
echo 'TBME_R462_REAL_XTEST_GTK_THRESHOLD_SPIN_INCREASE_DECREASE=PASS'
# Restart the exact GTK app with malformed private preferences. Its recovery
# button must be clickable, preserve the original bytes and reset opt-ins OFF.
kill "$pid" 2>/dev/null || true
wait "$pid" 2>/dev/null || true
pid=''
settings_file="$XDG_CONFIG_HOME/taskbarmonitorenhanced-native-preview/settings.ini"
printf '[NativeTemperatureAlert]\nenabled=maybe\nbell=true\nthresholdC=94\n' >"$settings_file"
chmod 0600 "$settings_file"
rejected_sha="$(sha256sum "$settings_file" | cut -d' ' -f1)"
if setting >/dev/null 2>&1; then
  echo 'R462 corrupt preferences unexpectedly accepted' >&2
  exit 8
fi
"$panel" >"$root/recovery-window.log" 2>&1 &
pid=$!
window=''
for i in {1..40}; do
  if ! kill -0 "$pid" 2>/dev/null; then
    cat "$root/recovery-window.log" >&2
    echo 'R462 recovery UI process exited' >&2
    exit 9
  fi
  window="$(xdotool search --onlyvisible --name '^TaskbarMonitorEnhanced Native Linux$' 2>/dev/null | head -n 1 || true)"
  [[ -n "$window" ]] && break
  sleep 0.15
done
if [[ -z "$window" ]]; then
  echo 'R462 recovery window missing' >&2
  exit 10
fi
recovered=false
for y in 100 115 130 145 160; do
  xdotool mousemove --window "$window" 180 "$y" click --clearmodifiers 1
  sleep 0.15
  if [[ "$(setting 2>/dev/null || true)" == 'alert=false bell=false thresholdC=85' ]]; then
    recovered=true
    break
  fi
done
if [[ "$recovered" != true ]]; then
  echo 'R462 recovery button did not restore defaults' >&2
  exit 11
fi
test -f "$settings_file.rejected"
test "$(sha256sum "$settings_file.rejected" | cut -d' ' -f1)" = "$rejected_sha"
test "$(stat -c %a "$settings_file")" = 600
if "$panel" --recover-settings >/dev/null 2>&1; then
  echo 'R462 repeated recovery unexpectedly accepted' >&2
  exit 12
fi
echo 'TBME_R462_REAL_XTEST_GTK_RECOVERY_CLICK_PRESERVES_ORIGINAL_BYTES=PASS'
