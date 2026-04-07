// AntiCheat.mm - Bypass Roblox's anti-cheat checks
// Hooks access, fopen, dlopen to hide jailbreak indicators

#import "AntiCheat.h"
#import <substrate.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <sys/stat.h>
#import <unistd.h>

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
    "/System/Library/LaunchDaemons/com.ikey.bbot.plist",
    "/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist",
    "/var/mobile/Library/SBSettings/Themes",
    "/var/cache/apt",
    "/var/lib/cydia",
    "/private/var/tmp/cydia.log",
    "/private/var/mobile/Library/Cydia",
    "/Applications/FakeCarrier.app",
    "/Applications/Icy.app",
    "/Applications/MxTube.app",
    "/Applications/RockApp.app",
    "/Applications/SBSettings.app",
    "/Applications/WinterBoard.app",
    "/Applications/blackra1n.app",
    "/Applications/Loader.app",
    NULL
};

static int (*orig_access)(const char *, int);

static int hooked_access(const char *path, int mode) {
    if (!path) return orig_access(path, mode);
    for (int i = 0; jailbreakPaths[i]; i++) {
        if (strncmp(path, jailbreakPaths[i], strlen(jailbreakPaths[i])) == 0) {
            errno = ENOENT;
            return -1;
        }
    }
    if (strstr(path, "frida") || strstr(path, "FRIDA") || strstr(path, "re.frida") ||
        strstr(path, "substrate") || strstr(path, "Substrate")) {
        errno = ENOENT;
        return -1;
    }
    return orig_access(path, mode);
}

static FILE *(*orig_fopen)(const char *, const char *);

static FILE* hooked_fopen(const char *path, const char *mode) {
    if (!path) return orig_fopen(path, mode);
    for (int i = 0; jailbreakPaths[i]; i++) {
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

static void* (*orig_dlopen)(const char *, int);

static void* hooked_dlopen(const char *path, int mode) {
    if (path && (strstr(path, "frida") || strstr(path, "substrate"))) {
        return NULL;
    }
    return orig_dlopen(path, mode);
}

static int (*orig_stat)(const char *, struct stat *);

static int hooked_stat(const char *path, struct stat *buf) {
    if (!path) return orig_stat(path, buf);
    for (int i = 0; jailbreakPaths[i]; i++) {
        if (strncmp(path, jailbreakPaths[i], strlen(jailbreakPaths[i])) == 0) {
            errno = ENOENT;
            return -1;
        }
    }
    return orig_stat(path, buf);
}

void AntiCheatBypass() {
    NSLog(@"[RobloxExecutor] Applying anti-cheat bypasses...");

    MSHookFunction((void *)access, (void *)hooked_access, (void **)&orig_access);
    NSLog(@"[RobloxExecutor] Hooked access()");

    MSHookFunction((void *)fopen, (void *)hooked_fopen, (void **)&orig_fopen);
    NSLog(@"[RobloxExecutor] Hooked fopen()");

    MSHookFunction((void *)dlopen, (void *)hooked_dlopen, (void **)&orig_dlopen);
    NSLog(@"[RobloxExecutor] Hooked dlopen()");

    void *stat_ptr = dlsym(RTLD_DEFAULT, "stat");
    if (stat_ptr) {
        MSHookFunction(stat_ptr, (void *)hooked_stat, (void **)&orig_stat);
        NSLog(@"[RobloxExecutor] Hooked stat()");
    }

    unsetenv("DYLD_INSERT_LIBRARIES");
    unsetenv("DYLD_FRAMEWORK_PATH");
    unsetenv("DYLD_LIBRARY_PATH");
    unsetenv("DYLD_PRINT_LIBRARIES");
    NSLog(@"[RobloxExecutor] Anti-cheat bypasses applied!");
}
