#pragma once
// Read-only Linux hwmon CPU thermal adapter; absence is never reported as zero.
#include <cstdint>
#include <fstream>
#include <sstream>
#include <string>

// Public kernel hwmon tempN_input values are in milli-Celsius.
inline bool parse_linux_cpu_millicelsius(const std::string& raw,double& celsius) {
    std::istringstream input(raw);
    std::int64_t milli=0;
    if(!(input>>milli))return false;
    input>>std::ws;
    if(!input.eof()||milli<0||milli>150000)return false;
    celsius=static_cast<double>(milli)/1000.;
    return true;
}

// Distinguish CPU telemetry from acpitz, GPU and unrelated hwmon sensors.
// Prefer actual AMD die over its temperature-control offset (Tctl).
inline int linux_cpu_temperature_rank(const std::string& driver,
                                      const std::string& label,
                                      int channel,const char*& source) {
    source=nullptr;
    if(driver=="coretemp" && label.rfind("Package id ",0)==0) {
        source="coretemp:Package";return 100;
    }
    if(driver=="k10temp"||driver=="zenpower") {
        if(label=="Tdie") {
            source=driver=="k10temp"?"k10temp:Tdie":"zenpower:Tdie";
            return 95;
        }
        if(label=="Tctl") {
            source=driver=="k10temp"?"k10temp:Tctl":"zenpower:Tctl";
            return 75;
        }
    }
    if(driver=="peci_cputemp"&&channel==1&&label=="Die") {
        source="peci_cputemp:Die";return 90;
    }
    if(driver=="cpu_thermal"&&channel==1) {
        source="cpu_thermal:temp1";return 80;
    }
    if(driver=="x86_pkg_temp"&&channel==1) {
        source="x86_pkg_temp:temp1";return 80;
    }
    return -1;
}

inline bool cpu_temperature(CpuThermal& output,
                            const std::string& root="/sys/class/hwmon") {
    int bestRank=-1;
    double bestValue=0.;
    const char* bestSource=nullptr;
    // Numeric sysfs entries are kernel managed. Bounded scan, no external commands.
    for(int index=0;index<128;++index) {
        const std::string prefix=root+"/hwmon"+std::to_string(index)+"/";
        std::ifstream nameFile(prefix+"name");
        std::string driver;
        if(!std::getline(nameFile,driver))continue;
        if(driver!="coretemp"&&driver!="k10temp"&&driver!="zenpower"&&
           driver!="peci_cputemp"&&driver!="cpu_thermal"&&
           driver!="x86_pkg_temp")continue;
        for(int channel=1;channel<=16;++channel) {
            const std::string stem=prefix+"temp"+std::to_string(channel);
            std::ifstream labelFile(stem+"_label");
            std::string label;
            std::getline(labelFile,label);
            const char* source=nullptr;
            const int rank=linux_cpu_temperature_rank(driver,label,channel,source);
            if(rank<0)continue;
            std::ifstream inputFile(stem+"_input");
            std::string raw;
            if(!std::getline(inputFile,raw))continue;
            double value=0.;
            if(!parse_linux_cpu_millicelsius(raw,value))continue;
            if(rank>bestRank||(rank==bestRank&&value>bestValue)) {
                bestRank=rank;bestValue=value;bestSource=source;
            }
        }
    }
    if(bestRank<0)return false;
    output.celsius=bestValue;
    output.source=bestSource;
    return true;
}
