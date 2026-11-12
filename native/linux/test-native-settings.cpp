#include "ThermalAlert.hpp"
#include "SettingsRecovery.hpp"
#include <glib.h>
#include <glib/gstdio.h>
#include <cstdio>
#include <string>
#include <filesystem>
#include <fstream>
#include <unistd.h>
#include <sys/stat.h>

int main(int argc,char** argv) {
    if(argc!=2)return 2;
    const std::filesystem::path home(argv[1]);
    if(!std::filesystem::is_directory(home) ||
       !std::filesystem::is_empty(home))return 2;
    if(!g_setenv("XDG_CONFIG_HOME",home.string().c_str(),TRUE))return 2;
    std::string error;
    NativeSettings settings{};
    if(!load_native_settings(settings,error) || settings.alertEnabled ||
       settings.bellEnabled || settings.thresholdC!=85)return 1;
    if(std::filesystem::exists(native_settings_path()))return 1;
    NativeSettings wanted{true,true,91};
    if(!save_native_settings(wanted,error))return 1;
    if(!load_native_settings(settings,error) ||
       !settings.alertEnabled || !settings.bellEnabled ||
       settings.thresholdC!=91)return 1;
    struct stat info{};
    if(g_stat(native_settings_path().c_str(),&info)!=0 ||
       (info.st_mode & 077)!=0)return 1;
    std::ifstream read(native_settings_path());
    std::string contents((std::istreambuf_iterator<char>(read)),
                         std::istreambuf_iterator<char>());
    if(contents.find("thresholdC=91")==std::string::npos)return 1;
    if(save_native_settings(NativeSettings{true,true,49},error))return 1;
    NativeAlertState state{};
    auto step=native_alert_step(state,wanted,false,0.,0);
    if(step.warning || step.bell)return 1;
    step=native_alert_step(state,wanted,true,90.,1);
    if(step.warning || step.bell)return 1;
    step=native_alert_step(state,wanted,true,92.,2);
    if(!step.warning || !step.bell)return 1;
    step=native_alert_step(state,wanted,true,90.,3);
    if(!step.warning || step.bell)return 1;
    step=native_alert_step(state,wanted,true,92.,63);
    if(!step.warning || !step.bell)return 1;
    step=native_alert_step(state,wanted,true,87.,64);
    if(step.warning || step.bell)return 1;
    step=native_alert_step(state,NativeSettings{true,false,91},true,95.,65);
    if(!step.warning || step.bell)return 1;
    step=native_alert_step(state,wanted,false,0.,66);
    if(step.warning || step.bell)return 1;
    step=native_alert_step(state,NativeSettings{false,true,91},true,110.,67);
    if(step.warning || step.bell)return 1;
    {
        std::ofstream corrupt(native_settings_path(),std::ios::trunc);
        corrupt<<"[NativeTemperatureAlert]\n"
               <<"enabled=maybe\nbell=true\nthresholdC=91\n";
    }
    error.clear();
    if(load_native_settings(settings,error) || error.empty())return 1;
    if(save_native_settings(wanted,error))return 1;
    // An explicit recovery must preserve the malformed original bytes.
    const std::string malformed=
        "[NativeTemperatureAlert]\nenabled=maybe\nbell=true\nthresholdC=91\n";
    const std::string archive=native_settings_path()+".rejected";
    // Do not preserve a shared inode: a second hard link could mutate the
    // supposed archival bytes even after the first name was detached.
    const std::string alias=native_settings_path()+".other-hardlink";
    if(::link(native_settings_path().c_str(),alias.c_str())!=0)return 1;
    error.clear();
    if(recover_invalid_native_settings(error) || error.empty())return 1;
    if(g_file_test(archive.c_str(),G_FILE_TEST_EXISTS))return 1;
    if(::unlink(alias.c_str())!=0)return 1;
    error.clear();
    if(!recover_invalid_native_settings(error))return 1;
    if(!load_native_settings(settings,error) ||
       settings.alertEnabled || settings.bellEnabled ||
       settings.thresholdC!=85)return 1;
    std::ifstream previous(archive);
    const std::string backup((std::istreambuf_iterator<char>(previous)),
                             std::istreambuf_iterator<char>());
    if(backup!=malformed)return 1;
    error.clear();
    if(recover_invalid_native_settings(error) || error.empty())return 1;
    {
        std::ofstream secondCorruption(native_settings_path(),std::ios::trunc);
        secondCorruption<<"[NativeTemperatureAlert]\nenabled=nope\n";
    }
    error.clear();
    if(recover_invalid_native_settings(error) || error.empty())return 1;
    std::ifstream retained(archive);
    const std::string preserved((std::istreambuf_iterator<char>(retained)),
                                std::istreambuf_iterator<char>());
    if(preserved!=malformed)return 1;
    const auto bogus=native_settings_path();
    if(g_remove(bogus.c_str())!=0)return 1;
    if(symlink("/tmp/tbme-native-do-not-follow-target",bogus.c_str())!=0)return 1;
    error.clear();
    if(load_native_settings(settings,error) || error.empty())return 1;
    if(save_native_settings(wanted,error))return 1;
    error.clear();
    if(recover_invalid_native_settings(error) || error.empty())return 1;
    if(g_remove(bogus.c_str())!=0)return 1;
    // Global monotonic bell cooldown MUST survive cool/hot cycles, an
    // unavailable sensor, alert toggles and threshold changes.
    NativeSettings hot{true,true,91};
    NativeSettings disabled{false,true,91};
    NativeSettings higher{true,true,110};
    NativeAlertState throttled{};
    auto check=native_alert_step(throttled,hot,true,92.,100);
    if(!check.warning || !check.bell || throttled.lastBellSecond!=100)return 1;
    check=native_alert_step(throttled,hot,true,87.,101);
    if(check.warning || check.bell || throttled.lastBellSecond!=100)return 1;
    check=native_alert_step(throttled,hot,true,92.,102);
    if(!check.warning || check.bell)return 1;
    check=native_alert_step(throttled,hot,false,0.,103);
    if(check.warning || check.bell || throttled.lastBellSecond!=100)return 1;
    check=native_alert_step(throttled,hot,true,92.,104);
    if(!check.warning || check.bell)return 1;
    native_alert_reconfigure(throttled,hot,disabled);
    check=native_alert_step(throttled,disabled,true,92.,105);
    if(check.warning || check.bell || throttled.lastBellSecond!=100)return 1;
    native_alert_reconfigure(throttled,disabled,hot);
    check=native_alert_step(throttled,hot,true,92.,106);
    if(!check.warning || check.bell)return 1;
    native_alert_reconfigure(throttled,hot,higher);
    if(throttled.active || throttled.lastBellSecond!=100)return 1;
    check=native_alert_step(throttled,higher,true,108.,107);
    if(check.warning || check.bell)return 1;
    check=native_alert_step(throttled,higher,true,111.,108);
    if(!check.warning || check.bell)return 1;
    check=native_alert_step(throttled,higher,true,111.,159);
    if(!check.warning || check.bell)return 1;
    check=native_alert_step(throttled,higher,true,111.,160);
    if(!check.warning || !check.bell || throttled.lastBellSecond!=160)return 1;
    check=native_alert_step(throttled,higher,true,107.,161);
    if(check.warning || check.bell || throttled.lastBellSecond!=160)return 1;
    check=native_alert_step(throttled,higher,true,112.,162);
    if(!check.warning || check.bell)return 1;
    check=native_alert_step(throttled,higher,false,0.,163);
    if(check.warning || check.bell || throttled.lastBellSecond!=160)return 1;
    check=native_alert_step(throttled,higher,true,112.,220);
    if(!check.warning || !check.bell || throttled.lastBellSecond!=220)return 1;
    std::puts("TBME_R451_NATIVE_GLOBAL_BELL_COOLDOWN_AFTER_SENSOR_DROPOUT_AND_RECONFIG=PASS");    std::puts("TBME_NATIVE_SETTINGS_PERSISTENCE_RECOVERY_NO_OVERWRITE_AND_ALERT_COOLDOWN=PASS");
    return 0;
}
