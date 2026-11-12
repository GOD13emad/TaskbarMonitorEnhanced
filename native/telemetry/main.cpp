#include "sample.hpp"
#include <cerrno>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <thread>
static int self_test() {
    if(std::abs(percent({10,90},{60,140})-50.)>0.00001||
       percent({20,20},{10,30})!=-1.||
       percent({1,2},{1,2})!=-1.||
       percent({0,0},{10,0})!=100.) return 1;
#ifdef __APPLE__
    Cpu machBefore{},machAfter{};
    machBefore.machTicks=machAfter.machTicks=true;
    machBefore.userTicks=0xfffffffau; machAfter.userTicks=10u;
    machBefore.idleTicks=0xfffffffau; machAfter.idleTicks=10u;
    if(std::abs(percent(machBefore,machAfter)-50.)>0.00001)return 1;
    machAfter.idleTicks=machBefore.idleTicks;
    if(std::abs(percent(machBefore,machAfter)-100.)>0.00001)return 1;
#endif
    return 0;
}
static int emit_sample() {
    Cpu before,after;Mem m;
    if(!cpu(before)){std::fputs("CPU unavailable\n",stderr);return 3;}
    std::this_thread::sleep_for(std::chrono::milliseconds(200));
    if(!cpu(after)||!mem(m)){std::fputs("CPU/memory unavailable\n",stderr);return 3;}
    double load=percent(before,after);
    if(!std::isfinite(load)||load<0||load>100||!m.total||m.available>m.total) {
        std::fputs("invalid native sample\n",stderr);return 3;
    }
    if(std::printf("{\"schema\":1,\"platform\":\"%s\",\"cpuPercent\":%.3f,"
       "\"memoryTotalBytes\":%llu,\"memoryAvailableBytes\":%llu,"
       "\"cpuTemperatureC\":null,\"temperatureAvailable\":false}\n",
       platform,load,static_cast<unsigned long long>(m.total),
       static_cast<unsigned long long>(m.available))<0||std::fflush(stdout)!=0){
        std::fputs("telemetry output failed\n",stderr);return 4;
    }
    return 0;
}
int main(int argc,char** argv) {
    if(argc==2&&!std::strcmp(argv[1],"--self-test")) return self_test();
    if(argc==2&&!std::strcmp(argv[1],"--once")) return emit_sample();
    if(argc==3&&!std::strcmp(argv[1],"--samples")) {
        // Strict, bounded numeric input: no unbounded background process.
        const char* number=argv[2];
        if(!number||!*number){std::fputs("invalid sample count\n",stderr);return 2;}
        for(const char* cursor=number;*cursor;++cursor)
            if(*cursor<'0'||*cursor>'9'){
                std::fputs("invalid sample count\n",stderr);return 2;
            }
        errno=0;
        char* end=nullptr;
        const long count=std::strtol(number,&end,10);
        if(errno!=0||!end||*end!='\0'||count<1||count>60){
            std::fputs("sample count must be 1..60\n",stderr);return 2;
        }
        for(long n=0;n<count;++n) {
            int code=emit_sample();
            if(code!=0)return code;
        }
        return 0;
    }
    std::fputs("usage: tbme-native-probe --once|--self-test|--samples N (1..60)\n",stderr);
    return 2;
}