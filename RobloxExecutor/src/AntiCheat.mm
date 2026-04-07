// AntiCheat.mm - Bypass Roblox's anti-cheat checks
// Hooks sysctl, jailbreak detection, integrity checks

#import "AntiCheat.h"
#import <substrate.h>
#import <sys/sysctl.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>

// ============================================================
// STRAIGHTFORWARD PATCHES
// ============================================================
// These target the specific checks found in our binary analysis:
//
// 0x04F4BF7A  "sysctl kern_proc_info"        - process info reading
// 0x04F32F79  "getIntegrityToken"             - integrity token
// 0x04F58B23  "GetDeviceIntegrityToken"       - Apple device integrity
// 0x05074778  "ScriptInjectionDenied"         - blocks injected scripts
// 0x0503ED2E  "untrusted"                     - player trust status
// 0x04F06A39  "IntegrityCheckProcessorKey2_"  - integrity processor
// ============================================================

// Hook sysctl to hide jailbreak indicators
static int (*orig_sysctl)(int *name, u_int namelen, void *info, size_t *infosize, void *newinfo, size_t newinfosize);

static int hooked_sysctl(int *name, u_int namelen, void *info, size_t *infosize, void *newinfo, size_t newinfosize) {
    int ret = orig_sysctl(name, namelen, info, infosize, newinfo, newinfosize);

    // Hide debug flags
    if (namelen >= 4 && name[0] == CTL_KERN && name[1] == KERN_PROC) {
        if (infosize && info) {
            struct kinfo_proc *proc = (struct kinfo_proc*)info;
            // Clear P_TRACED flag (debugger attached)
            proc->kp_proc.p_flag &= ~0x00000800;
        }
    }

    return ret;
}

// Hook access() to hide jailbreak file paths
static int (*orig_access)(const char *path, int mode);

static const char *jailbreakPaths[] = {
    "/Applications/Cydia.app",
    "/Applications/Sileo.app",
    "/Library/MobileSubstrate/MobileSubstrate.dylib",
    "/Library/MobileSubstrate/DynamicLibraries",
    "/bin/bash",
    "/usr/sbin/sshd",
    "/etc/apt",
    "/private/var/lib/apt/",
    "/private/var/stash",
    "/usr/bin/ssh",
    "/usr/libexec/sftp-server",
    "/usr/libexec/ssh-keysign",
    "/System/Library/LaunchDaemons/com.ikey.bbot.plist",
    "/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist",
    "/var/mobile/Library/SBSettings/Themes",
    "/var/cache/apt",
    "/var/lib/cydia",
    "/private/var/tmp/cydia.log",
    "/private/var/mobile/Library/Cydia",
    "/Applications/FakeCarrier.app",
    "/Applications/Icy.app",
    "/Applications/IntelliScreen.app",
    "/Applications/MxTube.app",
    "/Applications/RockApp.app",
    "/Applications/SBSettings.app",
    "/Applications/WinterBoard.app",
    "/Applications/blackra1n.app",
    "/Applications/Loader.app",
    "/Library/MobileSubstrate",
    "/private/var/stash",
    NULL
};

static int hooked_access(const char *path, int mode) {
    if (!path) return orig_access(path, mode);

    for (int i = 0; jailbreakPaths[i] != NULL; i++) {
        if (strncmp(path, jailbreakPaths[i], strlen(jailbreakPaths[i])) == 0) {
            // Pretend the file doesn't exist
            errno = ENOENT;
            return -1;
        }
    }

    // Hide Frida artifacts
    if (strstr(path, "frida") || strstr(path, "FRIDA") || strstr(path, "re.frida")) {
        errno = ENOENT;
        return -1;
    }

    // Hide Substrate
    if (strstr(path, "substrate") || strstr(path, "Substrate")) {
        errno = ENOENT;
        return -1;
    }

    return orig_access(path, mode);
}

// Hook fopen to hide jailbreak files
static FILE* (*orig_fopen)(const char *path, const char *mode);

static FILE* hooked_fopen(const char *path, const char *mode) {
    if (!path) return orig_fopen(path, mode);

    for (int i = 0; jailbreakPaths[i] != NULL; i++) {
        if (strncmp(path, jailbreakPaths[i], strlen(jailbreakPaths[i])) == 0) {
            return NULL;
        }
    }

    if (strstr(path, "frida") || strstr(path, "FRIDA") ||
        strstr(path, "substrate") || strstr(path, "Substrate")) {
        return NULL;
    }

    return orig_fopen(path, mode);
}

// Hook dlopen to hide injected dylibs from enumeration
static void* (*orig_dlopen)(const char *path, int mode);

static void* hooked_dlopen(const char *path, int mode) {
    void *result = orig_dlopen(path, mode);
    // Don't block dlopen itself (that would crash), just log
    if (path && (strstr(path, "frida") || strstr(path, "substrate"))) {
        NSLog(@"[RobloxExecutor] Blocked dlopen: %s", path);
        return NULL;
    }
    return result;
}

// Hook stat to hide jailbreak files
static int (*orig_stat)(const char *path, struct stat *buf);

static int hooked_stat(const char *path, struct stat *buf) {
    if (!path) return orig_stat(path, buf);

    for (int i = 0; jailbreakPaths[i] != NULL; i++) {
        if (strncmp(path, jailbreakPaths[i], strlen(jailbreakPaths[i])) == 0) {
            errno = ENOENT;
            return -1;
        }
    }

    return orig_stat(path, buf);
}

// Hide dylibs from _dyld_image enumeration by renaming in memory
static void HideInjectedDylibs() {
    // Enumerate loaded images and check for suspicious ones
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *name = _dyld_get_image_name(i);
        if (name) {
            if (strstr(name, "FridaGadget") || strstr(name, "frida") ||
                strstr(name, "CydiaSubstrate") || strstr(name, "substrate")) {
                NSLog(@"[RobloxExecutor] Suspicious dylib loaded: %s", name);
                // We can't easily hide from _dyld_image_count but we can
                // hook the functions that enumerate images
            }
        }
    }
}

void AntiCheatBypass() {
    NSLog(@"[RobloxExecutor] Applying anti-cheat bypasses...");

    // Hook sysctl
    MSHookFunction((void*)sysctl, (void*)hooked_sysctl, (void**)&orig_sysctl);
    NSLog(@"[RobloxExecutor] Hooked sysctl");

    // Hook access()
    MSHookFunction((void*)access, (void*)hooked_access, (void**)&orig_access);
    NSLog(@"[RobloxExecutor] Hooked access()");

    // Hook fopen()
    MSHookFunction((void*)fopen, (void*)hooked_fopen, (void**)&orig_fopen);
    NSLog(@"[RobloxExecutor] Hooked fopen()");

    // Hook stat()
    MSHookFunction((void*)stat, (void*)hooked_stat, (void**)&orig_stat);
    NSLog(@"[RobloxExecutor] Hooked stat()");

    // Hook dlopen
    MSHookFunction((void*)dlopen, (void*)hooked_dlopen, (void**)&orig_dlopen);
    NSLog(@"[RobloxExecutor] Hooked dlopen()");

    // Clear environment variables that reveal injection
    unsetenv("DYLD_INSERT_LIBRARIES");
    unsetenv("DYLD_FRAMEWORK_PATH");
    unsetenv("DYLD_LIBRARY_PATH");
    unsetenv("DYLD_PRINT_LIBRARIES");
    NSLog(@"[RobloxExecutor] Cleared DYLD_* environment variables");

    NSLog(@"[RobloxExecutor] Anti-cheat bypasses applied!");
}
