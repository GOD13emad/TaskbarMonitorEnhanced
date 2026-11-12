// TaskbarMonitorEnhanced: experimental native Linux/macOS telemetry adapter.
// Read-only, no device drivers, privileges, audio, or installed app changes.
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <limits>
#include <thread>
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

struct Cpu { std::uint64_t busy=0, idle=0; };
struct Mem { std::uint64_t total=0, available=0; };
static double percent(Cpu a,Cpu b) {
    if (b.busy<a.busy||b.idle<a.idle) return -1.;
    auto used=b.busy-a.busy, idle=b.idle-a.idle;
    if (!used&&!idle) return -1.;
    return 100.*static_cast<double>(used)/static_cast<double>(used+idle);
}
#ifdef __linux__
static const char* platform="linux";
static bool cpu(Cpu& c) {
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
static bool mem(Mem& m) {
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
static const char* platform="macos";
static bool cpu(Cpu& c) {
    host_cpu_load_info_data_t info{};
    mach_msg_type_number_t count=HOST_CPU_LOAD_INFO_COUNT;
    if(host_statistics(mach_host_self(),HOST_CPU_LOAD_INFO,
       reinterpret_cast<host_info_t>(&info),&count)!=KERN_SUCCESS) return false;
    c.busy=static_cast<std::uint64_t>(info.cpu_ticks[CPU_STATE_USER])+
           info.cpu_ticks[CPU_STATE_SYSTEM]+info.cpu_ticks[CPU_STATE_NICE];
    c.idle=info.cpu_ticks[CPU_STATE_IDLE];return true;
}
static bool mem(Mem& m) {
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
static int self_test() {
    if(std::abs(percent({10,90},{60,140})-50.)>0.00001||
       percent({20,20},{10,30})!=-1.||
       percent({1,2},{1,2})!=-1.||
       percent({0,0},{10,0})!=100.) return 1;
    std::puts("TBME_NATIVE_SENSOR_SELFTEST=PASS");
    return 0;
}
int main(int argc,char** argv) {
    if(argc==2&&!std::strcmp(argv[1],"--self-test")) return self_test();
    if(argc!=2||std::strcmp(argv[1],"--once")) {
        std::fputs("usage: tbme-native-probe --once|--self-test\n",stderr);return 2;
    }
    Cpu before,after;Mem m;
    if(!cpu(before)){std::fputs("CPU unavailable\n",stderr);return 3;}
    std::this_thread::sleep_for(std::chrono::milliseconds(200));
    if(!cpu(after)||!mem(m)){std::fputs("CPU/memory unavailable\n",stderr);return 3;}
    double load=percent(before,after);
    if(!std::isfinite(load)||load<0||load>100||!m.total||m.available>m.total) {
        std::fputs("invalid native sample\n",stderr);return 3;
    }
    std::printf("{\"schema\":1,\"platform\":\"%s\",\"cpuPercent\":%.3f,"
       "\"memoryTotalBytes\":%llu,\"memoryAvailableBytes\":%llu,"
       "\"cpuTemperatureC\":null,\"temperatureAvailable\":false}\n",
       platform,load,static_cast<unsigned long long>(m.total),
       static_cast<unsigned long long>(m.available));
    return 0;
}
