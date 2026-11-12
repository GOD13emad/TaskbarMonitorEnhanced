// Experimental macOS AppKit menu bar: read-only CPU/RAM and per-user refresh choice.
#import <AppKit/AppKit.h>
#include "../telemetry/sample.hpp"
#include <cmath>
#include <cstdio>
#include <cstring>

// Apple's NSProcessInfo thermal state reports system thermal pressure, not
// CPU package temperature in Celsius. Do not invent a numeric reading.
struct NativeThermalDisplay {
    const char* name;
    bool warning;
    bool critical;
};
static NativeThermalDisplay native_thermal_display(NSProcessInfoThermalState state) {
    switch(state) {
        case NSProcessInfoThermalStateNominal: return {"nominal",false,false};
        case NSProcessInfoThermalStateFair: return {"fair",false,false};
        case NSProcessInfoThermalStateSerious: return {"serious",true,false};
        case NSProcessInfoThermalStateCritical: return {"critical",true,true};
        default: return {"unknown",false,false};
    }
}
static bool native_thermal_mapping_self_test() {
    const auto nominal=native_thermal_display(NSProcessInfoThermalStateNominal);
    const auto fair=native_thermal_display(NSProcessInfoThermalStateFair);
    const auto serious=native_thermal_display(NSProcessInfoThermalStateSerious);
    const auto critical=native_thermal_display(NSProcessInfoThermalStateCritical);
    const auto unknown=native_thermal_display(static_cast<NSProcessInfoThermalState>(-1));
    return !std::strcmp(nominal.name,"nominal") && !nominal.warning &&
           !std::strcmp(fair.name,"fair") && !fair.warning &&
           !std::strcmp(serious.name,"serious") && serious.warning &&
           !serious.critical && !std::strcmp(critical.name,"critical") &&
           critical.warning && critical.critical &&
           !std::strcmp(unknown.name,"unknown") && !unknown.warning;
}
static NSString* const kNativeRefreshKey=@"RefreshSeconds";
static NSString* const kNativePreferencesSuite=
    @"com.god13emad.taskbarmonitorenhanced.nativepreview.settings";

static NSUserDefaults* native_preferences() {
    return [[NSUserDefaults alloc] initWithSuiteName:kNativePreferencesSuite];
}
static NSInteger native_refresh_seconds(NSUserDefaults* prefs) {
    id value=[prefs objectForKey:kNativeRefreshKey];
    if(!value)return 2; // do not create settings on launch
    if(![value isKindOfClass:[NSNumber class]])return -1;
    // Reject fractional, NaN, infinite, and out-of-range stored numbers.
    // integerValue would silently truncate 2.5 to the permitted value 2.
    const double number=[value doubleValue];
    if(!std::isfinite(number))return -1;
    if(number==2.0)return 2;
    if(number==5.0)return 5;
    if(number==10.0)return 10;
    return -1;
}
static bool save_native_refresh_seconds(NSUserDefaults* prefs,NSInteger number) {
    if(number!=2 && number!=5 && number!=10)return false;
    [prefs setInteger:number forKey:kNativeRefreshKey];
    return native_refresh_seconds(prefs)==number; // system manages backing-store flush
}

@interface TBMENativeStatusDelegate : NSObject <NSApplicationDelegate> {
@private
    NSStatusItem* statusItem;
    NSMenuItem* detailItem;
    NSMenuItem* thermalItem;
    NSMenuItem* refreshItems[3];
    NSTimer* updateTimer;
    NSUserDefaults* preferences;
    NSInteger refreshSeconds;
    Cpu previous;
    bool havePrevious;
}
- (void)refresh:(NSTimer*)timer;
- (void)chooseRefreshSeconds:(NSMenuItem*)item;
- (void)showMetricsTitle:(NSString*)title;
@end

@implementation TBMENativeStatusDelegate
- (void)refreshSchedule {
    if(updateTimer)[updateTimer invalidate];
    updateTimer=[NSTimer scheduledTimerWithTimeInterval:
        static_cast<NSTimeInterval>(refreshSeconds)
        target:self selector:@selector(refresh:) userInfo:nil repeats:YES];
}
- (void)applicationDidFinishLaunching:(NSNotification*)notification {
    (void)notification;
    preferences=native_preferences();
    refreshSeconds=native_refresh_seconds(preferences);
    const bool invalidPreferences=refreshSeconds<0;
    if(invalidPreferences)refreshSeconds=2; // safe runtime fallback, no overwrite
    statusItem=[[NSStatusBar systemStatusBar]
                statusItemWithLength:NSVariableStatusItemLength];
    [statusItem.button setTitle:@"CPU / RAM ..."];
    NSMenu* menu=[[NSMenu alloc] initWithTitle:@"TaskbarMonitorEnhanced"];
    detailItem=[[NSMenuItem alloc] initWithTitle:@"Measuring CPU / RAM..."
        action:nil keyEquivalent:@""];
    [detailItem setEnabled:NO];
    [menu addItem:detailItem];
    thermalItem=[[NSMenuItem alloc] initWithTitle:@"System thermal state: measuring..."
        action:nil keyEquivalent:@""];
    [thermalItem setEnabled:NO];
    [menu addItem:thermalItem];
    NSMenu* refreshMenu=[[NSMenu alloc] initWithTitle:@"Refresh interval"];
    const NSInteger values[]={2,5,10};
    for(int i=0;i<3;++i) {
        NSString* title=[NSString stringWithFormat:@"%ld seconds",
                         static_cast<long>(values[i])];
        refreshItems[i]=[[NSMenuItem alloc] initWithTitle:title
            action:@selector(chooseRefreshSeconds:) keyEquivalent:@""];
        [refreshItems[i] setTag:values[i]];
        [refreshItems[i] setTarget:self];
        [refreshItems[i] setState:
            refreshSeconds==values[i]?NSControlStateValueOn:NSControlStateValueOff];
        [refreshMenu addItem:refreshItems[i]];
    }
    NSMenuItem* refreshRoot=[[NSMenuItem alloc] initWithTitle:@"Refresh interval"
        action:nil keyEquivalent:@""];
    [refreshRoot setSubmenu:refreshMenu];
    [menu addItem:refreshRoot];
    if(invalidPreferences) {
        NSMenuItem* invalid=[[NSMenuItem alloc]
            initWithTitle:@"Invalid saved interval; using 2 seconds"
            action:nil keyEquivalent:@""];
        [invalid setEnabled:NO];
        [menu addItem:invalid];
    }
    [menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem* quit=[[NSMenuItem alloc] initWithTitle:@"Quit"
        action:@selector(terminate:) keyEquivalent:@"q"];
    [quit setTarget:NSApp];
    [menu addItem:quit];
    [statusItem setMenu:menu];
    havePrevious=false;
    [self refresh:nil];
    [self refreshSchedule];
}
- (void)chooseRefreshSeconds:(NSMenuItem*)item {
    const NSInteger wanted=[item tag];
    if(!save_native_refresh_seconds(preferences,wanted)) {
        [detailItem setTitle:@"Refresh preference NOT saved"];
        return;
    }
    refreshSeconds=wanted;
    const NSInteger values[]={2,5,10};
    for(int i=0;i<3;++i)
        [refreshItems[i] setState:
            values[i]==refreshSeconds?NSControlStateValueOn:NSControlStateValueOff];
    [self refreshSchedule];
}
- (void)showMetricsTitle:(NSString*)title {
    const auto thermal=native_thermal_display([[NSProcessInfo processInfo] thermalState]);
    NSString* detail=[NSString stringWithFormat:
        @"System thermal state: %s (not CPU degrees)",thermal.name];
    [thermalItem setTitle:detail];
    if(thermal.warning) {
        NSString* prefix=thermal.critical?@"THERMAL CRITICAL | ":@"THERMAL HIGH | ";
        [statusItem.button setTitle:[prefix stringByAppendingString:title]];
    } else {
        [statusItem.button setTitle:title];
    }
}
- (void)refresh:(NSTimer*)timer {
    (void)timer;
    Cpu current{};
    Mem memory{};
    if(!cpu(current)||!mem(memory)||!memory.total||
       memory.available>memory.total) {
        [self showMetricsTitle:@"CPU / RAM unavailable"];
        [detailItem setTitle:@"Native sensor unavailable"];
        havePrevious=false;
        return;
    }
    const double load=havePrevious?percent(previous,current):-1.0;
    previous=current;
    havePrevious=true;
    const double ram=100.0*static_cast<double>(memory.total-memory.available)/
                     static_cast<double>(memory.total);
    if(!std::isfinite(load)||load<0.0||load>100.0||
       !std::isfinite(ram)||ram<0.0||ram>100.0) {
        [self showMetricsTitle:@"CPU / RAM ..."];
        [detailItem setTitle:@"Measuring CPU / RAM..."];
        return;
    }
    NSString* title=[NSString stringWithFormat:@"CPU %.0f%%  RAM %.0f%%",load,ram];
    [self showMetricsTitle:title];
    [detailItem setTitle:title];
}
@end

int main(int argc,char** argv) {
    @autoreleasepool {
        if(argc==2 && !std::strcmp(argv[1],"--self-test")) {
            Cpu c{};Mem m{};
            if(!cpu(c)||!mem(m)||!m.total||m.available>m.total)return 3;
            std::puts("TBME_MACOS_APPKIT_NATIVE_SENSOR_SELFTEST=PASS");
            return 0;
        }
        if(argc==2 && !std::strcmp(argv[1],"--test-thermal-policy")) {
            if(!native_thermal_mapping_self_test())return 3;
            std::puts("TBME_R455_MACOS_SYSTEM_THERMAL_WARNING_POLICY=PASS");
            return 0;
        }
        if(argc==2 && !std::strcmp(argv[1],"--thermal-state")) {
            const auto thermal=native_thermal_display(
                [[NSProcessInfo processInfo] thermalState]);
            std::printf("thermal=%s\n",thermal.name);
            return 0;
        }
        if(argc==2 && !std::strcmp(argv[1],"--settings")) {
            const NSInteger interval=native_refresh_seconds(native_preferences());
            if(interval<0) {
                std::fputs("Invalid stored refresh interval\n",stderr);return 3;
            }
            std::printf("refreshSeconds=%ld\n",static_cast<long>(interval));
            return 0;
        }
        if(argc==3 && !std::strcmp(argv[1],"--set-interval")) {
            NSInteger desired=-1;
            if(!std::strcmp(argv[2],"2"))desired=2;
            else if(!std::strcmp(argv[2],"5"))desired=5;
            else if(!std::strcmp(argv[2],"10"))desired=10;
            else return 2;
            NSUserDefaults* prefs=native_preferences();
            if(!save_native_refresh_seconds(prefs,desired)) {
                std::fputs("Cannot save macOS refresh preference\n",stderr);
                return 3;
            }
            if(native_refresh_seconds(prefs)!=desired)return 3;
            std::printf("refreshSeconds=%ld\n",static_cast<long>(desired));
            return 0;
        }
        if(argc!=1) {
            std::fputs("usage: tbme-macos-status [--self-test|--thermal-state|--test-thermal-policy|--settings|--set-interval 2/5/10]\n",stderr);
            return 2;
        }
        NSApplication* app=[NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
        TBMENativeStatusDelegate* delegate=[[TBMENativeStatusDelegate alloc]init];
        [app setDelegate:delegate];
        [app run];
    }
    return 0;
}
