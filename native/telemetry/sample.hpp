#pragma once
// Shared read-only platform adapter for the native CLI and the platform UIs.
// Semantics: system CPU tick delta and approximate available physical memory.
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <limits>
#ifdef __linux__
#include <fstream>
#include <sstream>
#include <string>
#elif defined(__APPLE__)
#include <mach/mach.h>
#include <sys/sysctl.h>
#else
#error Unsupported native telemetry platform
#endif
struct Cpu {
    std::uint64_t busy=0, idle=0;
#ifdef __APPLE__
    // Mach host_cpu_load_info uses independent 32-bit cumulative tick lanes.
    std::uint32_t userTicks=0, systemTicks=0, niceTicks=0, idleTicks=0;
    bool machTicks=false;
#endif
};
struct Mem { std::uint64_t total=0, available=0; };
struct CpuThermal {
    double celsius=0.;
    const char* source=nullptr; // static allowlisted driver/channel identifier
};
#ifdef __linux__
#include "linux_temperature.hpp"
#else
inline bool cpu_temperature(CpuThermal&) { return false; }
#endif
inline double percent(Cpu a,Cpu b) {
#ifdef __APPLE__
    if(a.machTicks && b.machTicks) {
        // Unsigned per-lane deltas handle the independent 32-bit counter wraps.
        // A 200ms interval cannot span 2^32 ticks of one Mach lane.
        auto tickDelta=[](std::uint32_t earlier,std::uint32_t later)->std::uint64_t {
            return static_cast<std::uint32_t>(later-earlier);
        };
        const std::uint64_t used=tickDelta(a.userTicks,b.userTicks)+
            tickDelta(a.systemTicks,b.systemTicks)+tickDelta(a.niceTicks,b.niceTicks);
        const std::uint64_t idle=tickDelta(a.idleTicks,b.idleTicks);
        if(used+idle==0)return -1.;
        return 100.*static_cast<double>(used)/static_cast<double>(used+idle);
    }
#endif
    if (b.busy<a.busy||b.idle<a.idle) return -1.;
    auto used=b.busy-a.busy, idle=b.idle-a.idle;
    if (!used&&!idle) return -1.;
    return 100.*static_cast<double>(used)/static_cast<double>(used+idle);
}
#ifdef __linux__
inline constexpr const char* platform="linux";
inline bool cpu(Cpu& c) {
    std::ifstream f("/proc/stat"); std::string line,tag;
    if (!std::getline(f,line)) return false;
    std::istringstream r(line);
    std::uint64_t user=0,nice=0,sys=0,idle=0,io=0,irq=0,soft=0,steal=0;
    if (!(r>>tag>>user>>nice>>sys>>idle)||tag!="cpu") return false;
    // Missing optional older-kernel fields remain zero.
    r>>io>>irq>>soft>>steal;
    c.busy=user+nice+sys+irq+soft+steal;
    c.idle=idle+io;
    // guest and guest_nice are included in user/nice; never add again.
    return true;
}
inline bool mem(Mem& m) {
    std::ifstream f("/proc/meminfo");
    std::string name,unit; std::uint64_t value=0,total=0,avail=0;
    while (f>>name>>value>>unit) {
        if(name=="MemTotal:") total=value;
        else if(name=="MemAvailable:") avail=value;
        if(total&&avail) break;
    }
    if(!total||!avail||avail>total||total>std::numeric_limits<std::uint64_t>::max()/1024) return false;
    m.total=total*1024; m.available=avail*1024; return true;
}
#elif defined(__APPLE__)
inline constexpr const char* platform="macos";
inline bool cpu(Cpu& c) {
    host_cpu_load_info_data_t info{};
    mach_msg_type_number_t count=HOST_CPU_LOAD_INFO_COUNT;
    if(host_statistics(mach_host_self(),HOST_CPU_LOAD_INFO,
       reinterpret_cast<host_info_t>(&info),&count)!=KERN_SUCCESS) return false;
    c.userTicks=static_cast<std::uint32_t>(info.cpu_ticks[CPU_STATE_USER]);
    c.systemTicks=static_cast<std::uint32_t>(info.cpu_ticks[CPU_STATE_SYSTEM]);
    c.niceTicks=static_cast<std::uint32_t>(info.cpu_ticks[CPU_STATE_NICE]);
    c.idleTicks=static_cast<std::uint32_t>(info.cpu_ticks[CPU_STATE_IDLE]);
    c.busy=static_cast<std::uint64_t>(c.userTicks)+c.systemTicks+c.niceTicks;
    c.idle=c.idleTicks;
    c.machTicks=true;
    return true;
}
inline bool mem(Mem& m) {
    std::uint64_t total=0;size_t size=sizeof(total);
    if(sysctlbyname("hw.memsize",&total,&size,nullptr,0)!=0||
       size!=sizeof(total)||!total) return false;
    vm_statistics64_data_t vm{};
    mach_msg_type_number_t count=HOST_VM_INFO64_COUNT;
    if(host_statistics64(mach_host_self(),HOST_VM_INFO64,
       reinterpret_cast<host_info64_t>(&vm),&count)!=KERN_SUCCESS) return false;
    vm_size_t page=0;
    if(host_page_size(mach_host_self(),&page)!=KERN_SUCCESS||!page) return false;
    // Approximate recoverable memory, not macOS memory pressure.
    const std::uint64_t pages=static_cast<std::uint64_t>(vm.free_count)+vm.inactive_count;
    m.total=total;m.available=pages>total/page?total:std::min(total,pages*page);
    return true;
}
#endif
