# Native Linux and macOS telemetry slice (experimental)

`tbme-native-probe` is the first platform-native, read-only TaskbarMonitorEnhanced sensor component for Linux and macOS. It is **not yet a complete desktop application**, installer or system tray/taskbar UI. Neither the Windows application nor immutable v1.7.10 release changes.

Build on Linux or macOS with a native C++17 compiler:

```sh
c++ -std=c++17 -O2 -Wall -Wextra -Werror -pedantic native/telemetry/main.cpp -o tbme-native-probe
./tbme-native-probe --self-test
./tbme-native-probe --once
```

The JSON schema 1 response exposes sampled system CPU usage (200 ms), memory total and available in **bytes**, `cpuTemperatureC:null` and `temperatureAvailable:false`. Missing counters fail closed with nonzero exit instead of invented readings. Linux reads the kernel's `/proc/stat` and `/proc/meminfo`. macOS uses the native Mach host statistics API and `sysctlbyname("hw.memsize")`. macOS available memory is an approximation, **not** a substitute for memory pressure. No sudo, third-party dependency or background service required.

CI compiles and runs both targets on independent hosted Ubuntu/macOS, validates JSON types, bounds and intentional unsupported-argument refusal. Acceptance applies only to this telemetry slice; native GPU/thermal service, UI, packaging, persistence, autostart, configuration and end-user tests remain open.

## Bounded NDJSON streaming

Use **./tbme-native-probe --samples 3** to emit exactly three complete JSON lines, one after each 200 ms kernel counter sample. Each line is flushed to stdout for future UI integration. The sample count must be decimal digits in the inclusive range 1..60; invalid counts exit 2 without telemetry output. Sensor read failures exit 3; output write failures exit 4. The original --once and --self-test contracts stay backward compatible. This bounded CLI is not a background daemon, desktop app, installer, or UI acceptance.