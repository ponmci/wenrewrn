#ifndef LuaVMHook_h
#define LuaVMHook_h

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

// Lua state type (opaque pointer)
typedef void* lua_State;

// Function pointer types for Luau VM
typedef int (*lua_resume_t)(lua_State *L, lua_State *from, int nargs);
typedef int (*lua_pcall_t)(lua_State *L, int nargs, int nresults, int errfunc);
typedef int (*luaL_loadbuffer_t)(lua_State *L, const char *buff, size_t sz, const char *name);
typedef lua_State* (*lua_newthread_t)(lua_State *L);
typedef void (*lua_settop_t)(lua_State *L, int idx);
typedef int (*lua_gettop_t)(lua_State *L);
typedef const char* (*lua_tolstring_t)(lua_State *L, int idx, size_t *len);
typedef void (*lua_pushstring_t)(lua_State *L, const char *s);
typedef void (*lua_pushcclosure_t)(lua_State *L, void(*fn)(void*), int n);

// Global state
extern lua_State *g_L;
extern uintptr_t g_base;
extern BOOL g_vmFound;
extern BOOL g_ready;

// Original function pointers (for calling through)
extern lua_resume_t orig_lua_resume;
extern lua_pcall_t orig_lua_pcall;
extern luaL_loadbuffer_t orig_lua_loadbuffer;
extern lua_newthread_t orig_lua_newthread;
extern lua_settop_t orig_lua_settop;
extern lua_gettop_t orig_lua_gettop;
extern lua_pushstring_t orig_lua_pushstring;
extern lua_tolstring_t orig_lua_tolstring;

// Initialize hooks
void HookLuaVM(void);

// Execute a Lua script string
int ExecuteScript(const char *script, const char *name);

// Get the main Lua state
lua_State* GetLuaState(void);

#ifdef __cplusplus
}
#endif

#endif
