#pragma once
// Experimental Linux-only, per-user settings. Never loads untrusted executable content.
#include <glib.h>
#include <glib/gstdio.h>
#include <string>
#include <cerrno>
#include <sys/stat.h>
#include <cstdint>

struct NativeSettings {
    bool alertEnabled=false;
    bool bellEnabled=false; // independently opt-in, default silent
    int thresholdC=85;
};

inline bool valid_native_settings(const NativeSettings& settings) {
    return settings.thresholdC>=50 && settings.thresholdC<=110;
}

inline std::string native_settings_directory() {
    return std::string(g_get_user_config_dir()) + "/taskbarmonitorenhanced-native-preview";
}
inline std::string native_settings_path() {
    return native_settings_directory() + "/settings.ini";
}
inline bool safe_native_settings_location(std::string& error) {
    const auto dir=native_settings_directory();
    const auto file=native_settings_path();
    if(g_file_test(dir.c_str(),G_FILE_TEST_IS_SYMLINK) ||
       g_file_test(file.c_str(),G_FILE_TEST_IS_SYMLINK)) {
        error="Settings symlink refused";
        return false;
    }
    GStatBuf info{};
    if(g_lstat(dir.c_str(),&info)==0 && !S_ISDIR(info.st_mode)) {
        error="Settings path is not a directory";
        return false;
    }
    if(g_lstat(file.c_str(),&info)==0) {
        if(!S_ISREG(info.st_mode) || info.st_size>4096) {
            error="Settings file must be a small regular file";
            return false;
        }
    } else if(errno!=ENOENT) {
        error="Cannot stat settings file";
        return false;
    }
    return true;
}

inline bool load_native_settings(NativeSettings& out,std::string& error) {
    NativeSettings proposed{}; // fail closed and do not enable sound
    if(!safe_native_settings_location(error))return false;
    const std::string file=native_settings_path();
    if(!g_file_test(file.c_str(),G_FILE_TEST_EXISTS)) {
        out=proposed;
        return true;
    }
    GKeyFile* key=g_key_file_new();
    GError* err=nullptr;
    if(!g_key_file_load_from_file(key,file.c_str(),G_KEY_FILE_KEEP_COMMENTS,&err)) {
        error=err ? err->message : "Cannot parse settings";
        if(err)g_error_free(err);
        g_key_file_free(key);
        return false;
    }
    constexpr const char* section="NativeTemperatureAlert";
    if(g_key_file_has_key(key,section,"enabled",nullptr)) {
        proposed.alertEnabled=g_key_file_get_boolean(key,section,"enabled",&err);
    }
    if(!err && g_key_file_has_key(key,section,"bell",nullptr)) {
        proposed.bellEnabled=g_key_file_get_boolean(key,section,"bell",&err);
    }
    if(!err && g_key_file_has_key(key,section,"thresholdC",nullptr)) {
        proposed.thresholdC=g_key_file_get_integer(key,section,"thresholdC",&err);
    }
    if(err) {
        error=err->message;
        g_error_free(err);
        g_key_file_free(key);
        return false;
    }
    g_key_file_free(key);
    if(!valid_native_settings(proposed)) {
        error="Temperature threshold out of supported range 50..110 C";
        return false;
    }
    out=proposed;
    return true;
}

inline bool save_native_settings(const NativeSettings& next,std::string& error) {
    if(!valid_native_settings(next)) {
        error="Refusing temperature threshold outside 50..110 C";
        return false;
    }
    NativeSettings current{};
    if(!load_native_settings(current,error))return false;
    const std::string dir=native_settings_directory();
    if(g_mkdir_with_parents(dir.c_str(),0700)!=0) {
        error="Cannot create user settings directory";
        return false;
    }
    if(!safe_native_settings_location(error))return false;
    const std::string file=native_settings_path();
    GKeyFile* key=g_key_file_new();
    GError* err=nullptr;
    // Preserve unrelated key-file settings during upgrades.
    if(g_file_test(file.c_str(),G_FILE_TEST_EXISTS) &&
       !g_key_file_load_from_file(key,file.c_str(),
                                 G_KEY_FILE_KEEP_COMMENTS,&err)) {
        error=err ? err->message : "Cannot preserve previous settings";
        if(err)g_error_free(err);
        g_key_file_free(key);
        return false;
    }
    constexpr const char* section="NativeTemperatureAlert";
    g_key_file_set_boolean(key,section,"enabled",next.alertEnabled);
    g_key_file_set_boolean(key,section,"bell",next.bellEnabled);
    g_key_file_set_integer(key,section,"thresholdC",next.thresholdC);
    gsize bytes=0;
    gchar* text=g_key_file_to_data(key,&bytes,&err);
    g_key_file_free(key);
    if(!text || err) {
        error=err ? err->message : "Cannot serialize settings";
        if(err)g_error_free(err);
        g_free(text);
        return false;
    }
    if(bytes>4096) {
        error="Settings exceed bounded file size";
        g_free(text);
        return false;
    }
    // Atomic replacement + fsync; never follows a settings-file symlink.
    const bool saved=g_file_set_contents_full(
        file.c_str(),text,static_cast<gssize>(bytes),
        static_cast<GFileSetContentsFlags>(G_FILE_SET_CONTENTS_CONSISTENT|
                                          G_FILE_SET_CONTENTS_DURABLE),
        0600,&err);
    g_free(text);
    if(!saved) {
        error=err ? err->message : "Cannot write settings";
        if(err)g_error_free(err);
        return false;
    }
    return true;
}
