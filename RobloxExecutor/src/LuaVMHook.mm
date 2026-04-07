// LuaVMHook.mm - Hooks into Roblox's Luau VM
// Offsets found via IDA analysis of RobloxLib (100,258,048 bytes)

#import "LuaVMHook.h"
#import <substrate.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>

// Global state
lua_State *g_L = NULL;
uintptr_t g_base = 0;
BOOL g_vmFound = NO;
BOOL g_ready = NO;

// Original function pointers
lua_resume_t orig_lua_resume = NULL;
lua_pcall_t orig_lua_pcall = NULL;
luaL_loadbuffer_t orig_lua_loadbuffer = NULL;
lua_newthread_t orig_lua_newthread = NULL;

// ============================================================
// HARDCODED OFFSETS FROM IDA ANALYSIS
// Found by: Strings window -> Xrefs -> function start
// ============================================================
// These are virtual addresses from IDA (relative to image base)
// At runtime: actual_addr = image_base + offset (ASLR handled by dyld)
//
// lua_resume:      sub_3EA097C  -> "cannot resume %s coroutine"
// lua_newthread:   sub_3EA07A8  -> "not enough memory" + "error in error handling"
// luaL_loadbuffer: sub_8C40C4  -> "Invalid Bytecode."
// ============================================================

#define LUA_RESUME_OFFSET        0x3EA097C
#define LUA_NEWTHREAD_OFFSET     0x3EA07A8
#define LUA_LOADBUFFER_OFFSET    0x8C40C4

// ============================================================
// HELPERS
// ============================================================

static uintptr_t GetRobloxLibBase() {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, "RobloxLib")) {
            return (uintptr_t)_dyld_get_image_header(i);
        }
    }
    NSLog(@"[RobloxExecutor] RobloxLib not found in loaded images");
    return 0;
}

static uintptr_t GetImageSlide() {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, "RobloxLib")) {
            return (uintptr_t)_dyld_get_image_vmaddr_slide(i);
        }
    }
    return 0;
}

// ============================================================
// HOOKED FUNCTIONS
// ============================================================

// Hooked lua_resume - captures lua_State* on first call
static int hooked_lua_resume(lua_State *L, lua_State *from, int nargs) {
    if (!g_L) {
        g_L = L;
        NSLog(@"[RobloxExecutor] Captured lua_State: %p", L);
    }
    return orig_lua_resume(L, from, nargs);
}

// Hooked lua_newthread - log thread creation
static lua_State* hooked_lua_newthread(lua_State *L) {
    lua_State *thread = orig_lua_newthread(L);
    NSLog(@"[RobloxExecutor] lua_newthread: L=%p thread=%p", L, thread);
    return thread;
}

// Hooked luaL_loadbuffer - log script loading
static int hooked_lua_loadbuffer(lua_State *L, const char *buff, size_t sz, const char *name) {
    NSLog(@"[RobloxExecutor] luaL_loadbuffer: name=%s size=%zu", name ? name : "nil", sz);
    return orig_lua_loadbuffer(L, buff, sz, name);
}

// ============================================================
// INITIALIZATION
// ============================================================

void HookLuaVM() {
    g_base = GetRobloxLibBase();
    if (!g_base) {
        NSLog(@"[RobloxExecutor] Failed to find RobloxLib base");
        return;
    }

    uintptr_t slide = GetImageSlide();
    NSLog(@"[RobloxExecutor] RobloxLib base: 0x%lx, slide: 0x%lx", (unsigned long)g_base, (unsigned long)slide);

    // Hook lua_resume
    uintptr_t resumeAddr = g_base + LUA_RESUME_OFFSET;
    NSLog(@"[RobloxExecutor] Hooking lua_resume at: 0x%lx", (unsigned long)resumeAddr);
    MSHookFunction((void*)resumeAddr, (void*)hooked_lua_resume, (void**)&orig_lua_resume);
    NSLog(@"[RobloxExecutor] Hooked lua_resume at 0x%lx", (unsigned long)resumeAddr);

    // Hook lua_newthread
    uintptr_t newthreadAddr = g_base + LUA_NEWTHREAD_OFFSET;
    NSLog(@"[RobloxExecutor] Hooking lua_newthread at: 0x%lx", (unsigned long)newthreadAddr);
    MSHookFunction((void*)newthreadAddr, (void*)hooked_lua_newthread, (void**)&orig_lua_newthread);
    NSLog(@"[RobloxExecutor] Hooked lua_newthread at 0x%lx", (unsigned long)newthreadAddr);

    // Hook luaL_loadbuffer
    uintptr_t loadbufferAddr = g_base + LUA_LOADBUFFER_OFFSET;
    NSLog(@"[RobloxExecutor] Hooking luaL_loadbuffer at: 0x%lx", (unsigned long)loadbufferAddr);
    MSHookFunction((void*)loadbufferAddr, (void*)hooked_lua_loadbuffer, (void**)&orig_lua_loadbuffer);
    NSLog(@"[RobloxExecutor] Hooked luaL_loadbuffer at 0x%lx", (unsigned long)loadbufferAddr);

    g_vmFound = YES;
    g_ready = YES;
    NSLog(@"[RobloxExecutor] All 3 Lua VM functions hooked!");
}

lua_State* GetLuaState() {
    return g_L;
}

// Execute a Lua script
// Called from the executor UI when user clicks "Execute"
int ExecuteScript(const char *script, const char *name) {
    if (!g_L) {
        NSLog(@"[RobloxExecutor] No Lua state! Cannot execute script.");
        return -1;
    }

    if (!orig_lua_newthread) {
        NSLog(@"[RobloxExecutor] lua_newthread not hooked!");
        return -2;
    }

    if (!orig_lua_loadbuffer) {
        NSLog(@"[RobloxExecutor] luaL_loadbuffer not hooked!");
        return -3;
    }

    // Create a new thread (coroutine) so we don't crash the main state
    lua_State *thread = orig_lua_newthread(g_L);
    if (!thread) {
        NSLog(@"[RobloxExecutor] Failed to create thread");
        return -4;
    }
    NSLog(@"[RobloxExecutor] Created thread: %p", thread);

    // Load the script
    int status = orig_lua_loadbuffer(thread, script, strlen(script), name);
    if (status != 0) {
        NSLog(@"[RobloxExecutor] Script load failed: %d", status);
        return status;
    }
    NSLog(@"[RobloxExecutor] Script loaded successfully");

    // Execute via lua_resume (Luau uses resume instead of pcall for threads)
    status = orig_lua_resume(thread, NULL, 0);
    if (status != 0) {
        NSLog(@"[RobloxExecutor] Script execution failed: %d", status);
        return status;
    }

    NSLog(@"[RobloxExecutor] Script executed successfully!");
    return 0;
}
