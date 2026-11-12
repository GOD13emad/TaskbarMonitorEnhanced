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
inline NativeAlertAction native_alert_step(NativeAlertState& state,
                                            const NativeSettings& config,
                                            bool available,double celsius,
                                            std::int64_t monotonicSecond) {
    if(!config.alertEnabled || !valid_native_settings(config) ||
       !available || !std::isfinite(celsius) ||
       celsius<0 || celsius>150) {
        state.active=false;
        state.lastBellSecond=-1;
        return {};
    }
    if(celsius>=config.thresholdC)state.active=true;
    else if(celsius<=config.thresholdC-3) {
        state.active=false;
        state.lastBellSecond=-1;
    }
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
