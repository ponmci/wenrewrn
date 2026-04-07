# Roblox Executor - iOS Theos Project

## What This Is
A Theos-based dylib that injects into Roblox iOS and provides a Lua script executor.

## Project Structure
```
RobloxExecutor/
├── Makefile              # Theos build config
├── RobloxExecutor.plist  # Bundle filter (only loads in Roblox)
├── control               # .deb package metadata
├── layout/               # Files installed by the .deb
│   └── Library/MobileSubstrate/DynamicLibraries/
│       ├── RobloxExecutor.dylib    # Built automatically
│       └── RobloxExecutor.plist    # Bundle filter
└── src/
    ├── Tweak.x          # Entry point (constructor, init)
    ├── LuaVMHook.h      # Lua VM hook declarations
    ├── LuaVMHook.mm     # Lua VM function finder + hooker
    ├── AntiCheat.h      # Anti-cheat bypass declarations
    ├── AntiCheat.mm     # sysctl/access/fopen hooks
    ├── Executor.h       # UI declarations
    └── Executor.mm      # Floating button + script editor
```

## How It Works

```
1. Tweak.x (constructor)
   └── AntiCheatBypass()     → Hook sysctl, access, fopen, stat, dlopen
   └── HookLuaVM()           → Find Lua VM by string cross-reference
       └── Find "cannot resume %s coroutine" in memory
       └── Search for ADRP+ADD that references it
       └── Find function start (STP/SUB SP prologue)
       └── MSHookFunction → hook lua_resume
       └── Captures lua_State* on first call
   └── SetupExecutorUI()     → Floating button + script editor

2. When user clicks Execute:
   └── ExecuteScript(script)
       └── lua_newthread(g_L)     → Create coroutine
       └── luaL_loadbuffer(...)   → Load script bytecode
       └── lua_pcall(...)         → Run script
```

## Building

### On macOS (with Theos installed):
```bash
# Set up Theos (if not already)
export THEOS=~/theos

# Build
cd RobloxExecutor
make

# Package as .deb
make package

# Output: packages/com.robloxexecutor_1.0.0_iphoneos-arm.deb
```

### Install on Device:
```bash
# Via SSH/SCP
scp packages/*.deb root@<device_ip>:/var/mobile/

# On device
dpkg -i com.robloxexecutor_1.0.0_iphoneos-arm.deb

# Or copy to Cydia auto-install
cp packages/*.deb /var/root/Media/Cydia/AutoInstall/
```

## What You Need to Update

### IMPORTANT: The string-based function finder may not find exact functions
because the ARM64 ADRP+ADD search has limitations. After the initial build:

1. Build and install on jailbroken device
2. Check the NSLog output in console:
   ```
   idevicesyslog | grep RobloxExecutor
   ```
3. If it says "Could not find Lua VM functions", you need to:
   - Open RobloxLib in Ghidra on macOS
   - Search for the strings listed in EXECUTOR_ANALYSIS.txt
   - Cross-reference them to find the actual function addresses
   - Update LuaVMHook.mm with hardcoded offsets:
     ```objc
     #define LUA_RESUME_ADDR   0x100XXXXXX  // from Ghidra
     MSHookFunction((void*)(g_base + LUA_RESUME_ADDR), ...);
     ```

### Anti-Cheat Updates
Roblox updates their anti-cheat regularly. If you get kicked:
1. Check the anti-cheat strings in EXECUTOR_ANALYSIS.txt
2. Find new detection functions in Ghidra
3. Add new hooks in AntiCheat.mm

## Required Offsets (fill in after Ghidra analysis)
```
lua_resume:        ___________ (from "cannot resume %s coroutine")
lua_pcall:         ___________ (from "stack overflow (%s)")
luaL_loadbuffer:   ___________ (from "Invalid Bytecode.")
lua_newthread:     ___________ (from "coroutine")
luaV_execute:      ___________ (from "attempt to %s a %s value")
lua_gettop:        ___________ (near lua_resume)
lua_settop:        ___________ (near lua_resume)
```
