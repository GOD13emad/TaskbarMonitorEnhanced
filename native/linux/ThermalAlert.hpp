#pragma once
#include "NativeSettings.hpp"
#include <cmath>
#include <cstdint>

// Explicit, independently opt-in thermal warning. This is NOT a safety shutdown.
struct NativeAlertState {
    bool active=false;
    std::int64_t lastBellSecond=-1;
};
struct NativeAlertAction {
    bool warning=false;
    bool bell=false;
};
// Reset the visual latch after threshold or enable-mode edits, while keeping
// the last audio request timestamp across config changes.
inline void native_alert_reconfigure(NativeAlertState& state,
                                      const NativeSettings& before,
                                      const NativeSettings& after) {
    if(!after.alertEnabled || !before.alertEnabled ||
       before.thresholdC!=after.thresholdC)state.active=false;
}
inline NativeAlertAction native_alert_step(NativeAlertState& state,
                                            const NativeSettings& config,
                                            bool available,double celsius,
                                            std::int64_t monotonicSecond) {
    if(!config.alertEnabled || !valid_native_settings(config) ||
       !available || !std::isfinite(celsius) ||
       celsius<0 || celsius>150) {
        // Sensor dropouts and disabled alerts must NOT re-arm the audio
        // cooldown: intermittent readings must not flood system bells.
        state.active=false;
        return {};
    }
    if(celsius>=config.thresholdC)state.active=true;
    else if(celsius<=config.thresholdC-3)state.active=false;
    bool beep=false;
    if(state.active && config.bellEnabled && monotonicSecond>=0 &&
       (state.lastBellSecond<0 ||
        (monotonicSecond>=state.lastBellSecond &&
         monotonicSecond-state.lastBellSecond>=60))) {
        beep=true;
        state.lastBellSecond=monotonicSecond;
    }
    return {state.active,beep};
}
