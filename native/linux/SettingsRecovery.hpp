#pragma once
// Explicit, user-invoked recovery of malformed native Linux preferences.
// Never silently overwrites the original or an existing recovery copy.
#include "NativeSettings.hpp"
#include <unistd.h>
#include <cerrno>
#include <cstring>
#include <sys/stat.h>

inline bool recover_invalid_native_settings(std::string& error) {
    NativeSettings current{};
    std::string oldError;
    if(load_native_settings(current,oldError)) {
        error="Settings are already valid; recovery refused";
        return false;
    }
    if(!safe_native_settings_location(error))return false;
    const std::string file=native_settings_path();
    const std::string archive=file+".rejected";
    GStatBuf original{};
    if(g_lstat(file.c_str(),&original)!=0 || !S_ISREG(original.st_mode) ||
       original.st_size<0 || original.st_size>4096) {
        error="Recovery requires a small regular malformed settings file";
        return false;
    }
    GStatBuf existingArchive{};
    errno=0;
    if(g_lstat(archive.c_str(),&existingArchive)==0 || errno!=ENOENT) {
        error="Recovery archive already exists or is inaccessible";
        return false;
    }
    // Same-directory hard link creates an exact-byte recovery copy and
    // atomically refuses to replace an existing file, including a symlink.
    if(::link(file.c_str(),archive.c_str())!=0) {
        error=std::string("Cannot preserve malformed preferences: ")+
              std::strerror(errno);
        return false;
    }
    GStatBuf preserved{},verifyOriginal{};
    if(g_lstat(archive.c_str(),&preserved)!=0 ||
       g_lstat(file.c_str(),&verifyOriginal)!=0 ||
       !S_ISREG(preserved.st_mode) ||
       preserved.st_dev!=original.st_dev ||
       preserved.st_ino!=original.st_ino ||
       verifyOriginal.st_dev!=original.st_dev ||
       verifyOriginal.st_ino!=original.st_ino) {
        ::unlink(archive.c_str());
        error="Settings changed during recovery; refusal";
        return false;
    }
    if(::unlink(file.c_str())!=0) {
        ::unlink(archive.c_str());
        error="Cannot detach malformed preferences";
        return false;
    }
    std::string saveError;
    if(save_native_settings(NativeSettings{},saveError))return true;
    // An unsuccessful write must retain the exact original bytes in archive.
    // Attempt to restore only if destination was not created by a failed save.
    if(g_lstat(file.c_str(),&verifyOriginal)!=0 && errno==ENOENT)
        ::link(archive.c_str(),file.c_str());
    error="Recovery archive preserved but defaults could not be saved: "+saveError;
    return false;
}
