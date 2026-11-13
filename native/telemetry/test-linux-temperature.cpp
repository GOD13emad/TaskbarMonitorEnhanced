#include "sample.hpp"
#include <cmath>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <string>

static bool write_value(const std::filesystem::path& file,const std::string& text) {
    std::ofstream stream(file);
    stream << text << '\n';
    return stream.good();
}
static bool reading(const std::filesystem::path& root,
                    double expected,const char* source) {
    CpuThermal thermal{};
    return cpu_temperature(thermal,root.string()) &&
           thermal.source && std::string(thermal.source)==source &&
           std::abs(thermal.celsius-expected)<0.0001;
}
int main(int argc,char** argv) {
    if(argc!=2)return 2;
    const std::filesystem::path root(argv[1]);
    if(!std::filesystem::exists(root)||!std::filesystem::is_directory(root)||
       !std::filesystem::is_empty(root))return 2;
    double parsed=0.;
    if(!parse_linux_cpu_millicelsius("56375",parsed)||
       std::abs(parsed-56.375)>0.0001 ||
       parse_linux_cpu_millicelsius("-10",parsed)||
       parse_linux_cpu_millicelsius("150001",parsed)||
       parse_linux_cpu_millicelsius("50000x",parsed)||
       parse_linux_cpu_millicelsius("NaN",parsed))return 1;
    CpuThermal thermal{};
    if(cpu_temperature(thermal,root.string()))return 1;
    const auto gpu=root/"hwmon0";
    std::filesystem::create_directory(gpu);
    if(!write_value(gpu/"name","amdgpu") ||
       !write_value(gpu/"temp1_label","edge") ||
       !write_value(gpu/"temp1_input","120000") ||
       cpu_temperature(thermal,root.string()))return 1;
    const auto amd=root/"hwmon1";
    std::filesystem::create_directory(amd);
    if(!write_value(amd/"name","k10temp") ||
       !write_value(amd/"temp1_label","Tctl") ||
       !write_value(amd/"temp1_input","56375") ||
       !reading(root,56.375,"k10temp:Tctl"))return 1;
    if(!write_value(amd/"temp2_label","Tdie") ||
       !write_value(amd/"temp2_input","47250") ||
       !reading(root,47.25,"k10temp:Tdie"))return 1;
    const auto intel=root/"hwmon2";
    std::filesystem::create_directory(intel);
    if(!write_value(intel/"name","coretemp") ||
       !write_value(intel/"temp1_label","Package id 0") ||
       !write_value(intel/"temp1_input","63000") ||
       !reading(root,63.,"coretemp:Package"))return 1;
    if(!write_value(intel/"temp1_input","invalid") ||
       !reading(root,47.25,"k10temp:Tdie"))return 1;
    // A package sensor can be temporarily unavailable: never emit fake 0 C.
    if(!write_value(amd/"temp2_input","-9999") ||
       !reading(root,56.375,"k10temp:Tctl"))return 1;
    if(!write_value(amd/"temp1_input","not-a-sensor") ||
       cpu_temperature(thermal,root.string()))return 1;
    std::puts("TBME_LINUX_TEMPERATURE_WHITELIST_AND_INVALID_REFUSAL=PASS");
    return 0;
}
