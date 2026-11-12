#include "ThermalAlert.hpp"
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
    const auto bogus=native_settings_path();
    if(g_remove(bogus.c_str())!=0)return 1;
    if(symlink("/tmp/tbme-native-do-not-follow-target",bogus.c_str())!=0)return 1;
    error.clear();
    if(load_native_settings(settings,error) || error.empty())return 1;
    if(save_native_settings(wanted,error))return 1;
    if(g_remove(bogus.c_str())!=0)return 1;
    std::puts("TBME_NATIVE_SETTINGS_ATOMIC_PERSISTENCE_FAIL_CLOSED_AND_ALERT_COOLDOWN=PASS");
    return 0;
}
