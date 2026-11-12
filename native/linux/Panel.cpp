// Experimental GTK3 desktop window; uses the same read-only native adapter as CLI.
#include <gtk/gtk.h>
#include "../telemetry/sample.hpp"
#include <cmath>
#include <cstdio>
#include <cstring>

struct PanelState {
    GtkWidget* label = nullptr;
    Cpu previous{};
    bool havePrevious = false;
    guint timer = 0;
};

static gboolean refresh_panel(gpointer data) {
    PanelState* state = static_cast<PanelState*>(data);
    Cpu current{};
    Mem memory{};
    if(!cpu(current) || !mem(memory) || !memory.total ||
       memory.available > memory.total) {
        gtk_label_set_text(GTK_LABEL(state->label), "CPU / RAM telemetry unavailable");
        state->havePrevious = false;
        return G_SOURCE_CONTINUE;
    }
    const double ram = 100.0 * static_cast<double>(memory.total-memory.available) /
                       static_cast<double>(memory.total);
    const double load = state->havePrevious ? percent(state->previous,current) : -1.0;
    state->previous = current;
    state->havePrevious = true;
    if(!std::isfinite(load) || load<0.0 || load>100.0 ||
       !std::isfinite(ram) || ram<0.0 || ram>100.0) {
        gtk_label_set_text(GTK_LABEL(state->label), "Measuring CPU / RAM...");
        return G_SOURCE_CONTINUE;
    }
    char message[160];
    CpuThermal thermal{};
    if(cpu_temperature(thermal)) {
        std::snprintf(message,sizeof(message),
                      "CPU %.1f%%  RAM %.1f%%  %s %.1f C",
                      load,ram,thermal.source,thermal.celsius);
    } else {
        std::snprintf(message,sizeof(message),"CPU %.1f%%  RAM %.1f%%",load,ram);
    }
    gtk_label_set_text(GTK_LABEL(state->label),message);
    return G_SOURCE_CONTINUE;
}

static void on_destroy(GtkWidget* widget,gpointer data) {
    (void)widget;
    PanelState* state=static_cast<PanelState*>(data);
    if(state->timer!=0)g_source_remove(state->timer);
    delete state;
}

static void activate(GtkApplication* app,gpointer data) {
    (void)data;
    GtkWindow* existing=gtk_application_get_active_window(app);
    if(existing) {
        gtk_window_present(existing);
        return;
    }
    GtkWidget* window=gtk_application_window_new(app);
    gtk_window_set_title(GTK_WINDOW(window),"TaskbarMonitorEnhanced Native Linux");
    gtk_window_set_default_size(GTK_WINDOW(window),475,92);
    GtkWidget* label=gtk_label_new("Measuring CPU / RAM...");
    gtk_label_set_xalign(GTK_LABEL(label),0.5f);
    gtk_container_add(GTK_CONTAINER(window),label);
    PanelState* state=new PanelState();
    state->label=label;
    g_signal_connect(window,"destroy",G_CALLBACK(on_destroy),state);
    refresh_panel(state);
    state->timer=g_timeout_add_seconds(2,refresh_panel,state);
    gtk_widget_show_all(window);
}

int main(int argc,char** argv) {
    if(argc==2 && !std::strcmp(argv[1],"--self-test")) {
        Cpu counter{};Mem memory{};
        if(!cpu(counter)||!mem(memory)||!memory.total||
           memory.available>memory.total)return 3;
        std::puts("TBME_LINUX_GTK3_NATIVE_SENSOR_SELFTEST=PASS");
        return 0;
    }
    if(argc!=1) {
        std::fputs("usage: tbme-linux-panel [--self-test]\n",stderr);
        return 2;
    }
    GtkApplication* app=gtk_application_new(
        "com.god13emad.taskbarmonitorenhanced",G_APPLICATION_DEFAULT_FLAGS);
    g_signal_connect(app,"activate",G_CALLBACK(activate),nullptr);
    const int code=g_application_run(G_APPLICATION(app),argc,argv);
    g_object_unref(app);
    return code;
}
