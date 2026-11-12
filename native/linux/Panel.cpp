// Experimental GTK3 native Linux UI. Warning is advisory, opt-in and not a shutdown.
#include <gtk/gtk.h>
#include "../telemetry/sample.hpp"
#include "NativeSettings.hpp"
#include "ThermalAlert.hpp"
#include <cerrno>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>

struct PanelState {
    GtkWidget *label=nullptr, *feedback=nullptr, *enable=nullptr,
              *bell=nullptr, *threshold=nullptr;
    Cpu previous{};
    bool havePrevious=false, settingsValid=true, synchronizing=false;
    guint timer=0;
    NativeSettings settings{};
    NativeAlertState warning{};
};

static void restore_controls(PanelState* state) {
    state->synchronizing=true;
    gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(state->enable),state->settings.alertEnabled);
    gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(state->bell),state->settings.bellEnabled);
    gtk_spin_button_set_value(GTK_SPIN_BUTTON(state->threshold),state->settings.thresholdC);
    state->synchronizing=false;
}
static void persist_controls(PanelState* state) {
    if(state->synchronizing || !state->settingsValid)return;
    NativeSettings next{
        gtk_toggle_button_get_active(GTK_TOGGLE_BUTTON(state->enable))!=0,
        gtk_toggle_button_get_active(GTK_TOGGLE_BUTTON(state->bell))!=0,
        gtk_spin_button_get_value_as_int(GTK_SPIN_BUTTON(state->threshold))
    };
    std::string error;
    if(!save_native_settings(next,error)) {
        restore_controls(state);
        std::string message="Settings NOT saved: "+error;
        gtk_label_set_text(GTK_LABEL(state->feedback),message.c_str());
        return;
    }
    state->settings=next;
    if(!next.alertEnabled)state->warning={};
    gtk_label_set_text(GTK_LABEL(state->feedback),
                       "Settings saved; warning is advisory, not a safety shutdown.");
}
static void on_toggle(GtkToggleButton*,gpointer data) {
    persist_controls(static_cast<PanelState*>(data));
}
static void on_threshold(GtkSpinButton*,gpointer data) {
    persist_controls(static_cast<PanelState*>(data));
}

static gboolean refresh_panel(gpointer data) {
    auto* state=static_cast<PanelState*>(data);
    Cpu current{};
    Mem memory{};
    const bool cpuOk=cpu(current);
    const bool memoryOk=mem(memory)&&memory.total>0 &&
                        memory.available<=memory.total;
    double load=-1.;
    if(cpuOk && state->havePrevious)load=percent(state->previous,current);
    state->havePrevious=cpuOk;
    if(cpuOk)state->previous=current;

    CpuThermal temp{};
    const bool available=cpu_temperature(temp);
    const auto action=native_alert_step(
        state->warning,state->settings,available,temp.celsius,
        g_get_monotonic_time()/G_USEC_PER_SEC);
    GtkStyleContext* style=gtk_widget_get_style_context(state->label);
    if(action.warning)gtk_style_context_add_class(style,"tbme-thermal-warning");
    else gtk_style_context_remove_class(style,"tbme-thermal-warning");
    char metrics[120];
    if(cpuOk && memoryOk && std::isfinite(load) && load>=0 && load<=100) {
        const double ram=100.*static_cast<double>(memory.total-memory.available)/
                          static_cast<double>(memory.total);
        std::snprintf(metrics,sizeof(metrics),"CPU %.1f%%  RAM %.1f%%",load,ram);
    } else if(cpuOk && memoryOk) {
        std::snprintf(metrics,sizeof(metrics),"Measuring CPU / RAM...");
    } else {
        std::snprintf(metrics,sizeof(metrics),"CPU / RAM telemetry unavailable");
    }
    std::string message=action.warning?"HIGH CPU TEMPERATURE — ":"";
    message+=metrics;
    if(available) {
        char thermal[96];
        std::snprintf(thermal,sizeof(thermal),"  %s %.1f C",
                      temp.source,temp.celsius);
        message+=thermal;
    } else message+="  CPU temperature unavailable";
    gtk_label_set_text(GTK_LABEL(state->label),message.c_str());
    if(action.bell) {
        GdkDisplay* display=gtk_widget_get_display(state->label);
        if(display)gdk_display_beep(display);
    }
    return G_SOURCE_CONTINUE;
}

static void on_destroy(GtkWidget*,gpointer data) {
    auto* state=static_cast<PanelState*>(data);
    if(state->timer)g_source_remove(state->timer);
    delete state;
}
static void activate(GtkApplication* app,gpointer) {
    GtkWindow* existing=gtk_application_get_active_window(app);
    if(existing){gtk_window_present(existing);return;}
    GtkWidget* window=gtk_application_window_new(app);
    gtk_window_set_title(GTK_WINDOW(window),"TaskbarMonitorEnhanced Native Linux");
    gtk_window_set_default_size(GTK_WINDOW(window),640,180);
    GtkWidget* box=gtk_box_new(GTK_ORIENTATION_VERTICAL,10);
    gtk_container_set_border_width(GTK_CONTAINER(box),12);
    gtk_container_add(GTK_CONTAINER(window),box);
    auto* state=new PanelState();
    std::string settingsError;
    state->settingsValid=load_native_settings(state->settings,settingsError);
    state->label=gtk_label_new("Measuring CPU / RAM...");
    gtk_label_set_xalign(GTK_LABEL(state->label),0.f);
    gtk_box_pack_start(GTK_BOX(box),state->label,FALSE,FALSE,0);
    GtkCssProvider* provider=gtk_css_provider_new();
    gtk_css_provider_load_from_data(
        provider,".tbme-thermal-warning {color:#df2929;font-weight:bold;}",
        -1,nullptr);
    gtk_style_context_add_provider(gtk_widget_get_style_context(state->label),
        GTK_STYLE_PROVIDER(provider),GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
    g_object_unref(provider);
    GtkWidget* controls=gtk_box_new(GTK_ORIENTATION_HORIZONTAL,12);
    gtk_box_pack_start(GTK_BOX(box),controls,FALSE,FALSE,0);
    state->enable=gtk_check_button_new_with_label("Visual warning");
    state->bell=gtk_check_button_new_with_label("System bell (opt-in)");
    GtkWidget* thresholdLabel=gtk_label_new("Threshold (C):");
    state->threshold=gtk_spin_button_new_with_range(50.,110.,1.);
    gtk_box_pack_start(GTK_BOX(controls),state->enable,FALSE,FALSE,0);
    gtk_box_pack_start(GTK_BOX(controls),state->bell,FALSE,FALSE,0);
    gtk_box_pack_start(GTK_BOX(controls),thresholdLabel,FALSE,FALSE,0);
    gtk_box_pack_start(GTK_BOX(controls),state->threshold,FALSE,FALSE,0);
    state->feedback=gtk_label_new("No thermal shutdown; physical audio unverified.");
    gtk_label_set_xalign(GTK_LABEL(state->feedback),0.f);
    gtk_box_pack_start(GTK_BOX(box),state->feedback,FALSE,FALSE,0);
    restore_controls(state);
    if(!state->settingsValid) {
        std::string message="Invalid settings; controls disabled: "+settingsError;
        gtk_label_set_text(GTK_LABEL(state->feedback),message.c_str());
        gtk_widget_set_sensitive(state->enable,FALSE);
        gtk_widget_set_sensitive(state->bell,FALSE);
        gtk_widget_set_sensitive(state->threshold,FALSE);
    }
    g_signal_connect(state->enable,"toggled",G_CALLBACK(on_toggle),state);
    g_signal_connect(state->bell,"toggled",G_CALLBACK(on_toggle),state);
    g_signal_connect(state->threshold,"value-changed",G_CALLBACK(on_threshold),state);
    g_signal_connect(window,"destroy",G_CALLBACK(on_destroy),state);
    refresh_panel(state);
    state->timer=g_timeout_add_seconds(2,refresh_panel,state);
    gtk_widget_show_all(window);
}

static int show_settings() {
    NativeSettings config{};
    std::string error;
    if(!load_native_settings(config,error)) {
        std::fprintf(stderr,"Invalid native settings: %s\n",error.c_str());
        return 3;
    }
    std::printf("alert=%s bell=%s thresholdC=%d\n",
        config.alertEnabled?"true":"false",
        config.bellEnabled?"true":"false",config.thresholdC);
    return 0;
}
static int update_settings(const char* command,const char* value) {
    NativeSettings next{};
    std::string error;
    if(!load_native_settings(next,error)) {
        std::fprintf(stderr,"Settings invalid: %s\n",error.c_str());
        return 3;
    }
    if(std::strcmp(command,"--set-threshold")==0) {
        if(!*value)return 2;
        for(const char* c=value;*c;++c)if(*c<'0'||*c>'9')return 2;
        errno=0;
        char* end=nullptr;
        const long n=std::strtol(value,&end,10);
        if(errno || !end || *end || n<50 || n>110)return 2;
        next.thresholdC=static_cast<int>(n);
    } else if(std::strcmp(command,"--set-alert")==0 ||
              std::strcmp(command,"--set-bell")==0) {
        if(std::strcmp(value,"true")!=0 && std::strcmp(value,"false")!=0)
            return 2;
        const bool enabled=std::strcmp(value,"true")==0;
        if(std::strcmp(command,"--set-alert")==0)next.alertEnabled=enabled;
        else next.bellEnabled=enabled;
    } else return 2;
    if(!save_native_settings(next,error)) {
        std::fprintf(stderr,"Settings write refused: %s\n",error.c_str());
        return 3;
    }
    return show_settings();
}
int main(int argc,char** argv) {
    // Noninteractive modes never create a GTK session or modify global settings.
    if(argc==2 && !std::strcmp(argv[1],"--settings"))return show_settings();
    if(argc==3)return update_settings(argv[1],argv[2]);
    if(argc==2 && !std::strcmp(argv[1],"--probe-temperature")) {
        CpuThermal thermal{};
        if(!cpu_temperature(thermal)) {
            std::fputs("CPU thermal sensor unavailable\n",stderr);return 3;
        }
        if(std::printf("%.3f %s\n",thermal.celsius,thermal.source)<0 ||
           std::fflush(stdout)!=0)return 4;
        return 0;
    }
    if(argc==2 && !std::strcmp(argv[1],"--self-test")) {
        Cpu counter{};Mem memory{};
        if(!cpu(counter)||!mem(memory)||!memory.total||
           memory.available>memory.total)return 3;
        std::puts("TBME_LINUX_GTK3_NATIVE_SENSOR_SELFTEST=PASS");
        return 0;
    }
    if(argc!=1) {
        std::fputs("usage: tbme-linux-panel [--self-test|--probe-temperature|--settings|--set-alert true/false|--set-bell true/false|--set-threshold 50..110]\n",stderr);
        return 2;
    }
    GtkApplication* app=gtk_application_new(
        "com.god13emad.taskbarmonitorenhanced",G_APPLICATION_DEFAULT_FLAGS);
    g_signal_connect(app,"activate",G_CALLBACK(activate),nullptr);
    const int code=g_application_run(G_APPLICATION(app),argc,argv);
    g_object_unref(app);
    return code;
}
