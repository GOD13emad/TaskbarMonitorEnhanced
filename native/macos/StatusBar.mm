// Experimental AppKit status-bar UI; native read-only counters, no helper process.
#import <AppKit/AppKit.h>
#include "../telemetry/sample.hpp"
#include <cmath>
#include <cstdio>
#include <cstring>

@interface TBMENativeStatusDelegate : NSObject <NSApplicationDelegate> {
@private
    NSStatusItem* statusItem;
    NSMenuItem* detailItem;
    NSTimer* updateTimer;
    Cpu previous;
    bool havePrevious;
}
- (void)refresh:(NSTimer*)timer;
@end

@implementation TBMENativeStatusDelegate
- (void)applicationDidFinishLaunching:(NSNotification*)notification {
    (void)notification;
    statusItem=[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [statusItem.button setTitle:@"CPU / RAM ..."];
    NSMenu* menu=[[NSMenu alloc] initWithTitle:@"TaskbarMonitorEnhanced"];
    detailItem=[[NSMenuItem alloc] initWithTitle:@"Measuring CPU / RAM..."
        action:nil keyEquivalent:@""];
    [detailItem setEnabled:NO];
    [menu addItem:detailItem];
    [menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem* quit=[[NSMenuItem alloc] initWithTitle:@"Quit"
        action:@selector(terminate:) keyEquivalent:@"q"];
    [quit setTarget:NSApp];
    [menu addItem:quit];
    [statusItem setMenu:menu];
    havePrevious=false;
    [self refresh:nil];
    updateTimer=[NSTimer scheduledTimerWithTimeInterval:2.0
        target:self selector:@selector(refresh:) userInfo:nil repeats:YES];
}
- (void)refresh:(NSTimer*)timer {
    (void)timer;
    Cpu current{};
    Mem memory{};
    if(!cpu(current)||!mem(memory)||!memory.total||
       memory.available>memory.total) {
        [statusItem.button setTitle:@"CPU / RAM unavailable"];
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
        [statusItem.button setTitle:@"CPU / RAM ..."];
        [detailItem setTitle:@"Measuring CPU / RAM..."];
        return;
    }
    NSString* title=[NSString stringWithFormat:@"CPU %.0f%%  RAM %.0f%%",load,ram];
    [statusItem.button setTitle:title];
    [detailItem setTitle:title];
}
@end

int main(int argc,char** argv) {
    if(argc==2&&!std::strcmp(argv[1],"--self-test")) {
        Cpu c{};Mem m{};
        if(!cpu(c)||!mem(m)||!m.total||m.available>m.total)return 3;
        std::puts("TBME_MACOS_APPKIT_NATIVE_SENSOR_SELFTEST=PASS");
        return 0;
    }
    if(argc!=1) {
        std::fputs("usage: tbme-macos-status [--self-test]\n",stderr);
        return 2;
    }
    @autoreleasepool {
        NSApplication* app=[NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
        TBMENativeStatusDelegate* delegate=[[TBMENativeStatusDelegate alloc]init];
        [app setDelegate:delegate];
        [app run];
    }
    return 0;
}
