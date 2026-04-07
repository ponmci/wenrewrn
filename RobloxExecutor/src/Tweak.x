// Tweak.x - Main entry point
// Injected into Roblox via MobileSubstrate

#import <substrate.h>
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "LuaVMHook.h"
#import "AntiCheat.h"
#import "Executor.h"

// This runs when the dylib is loaded into Roblox
__attribute__((constructor))
static void RobloxExecutorInit() {
    NSLog(@"[RobloxExecutor] Loaded into process: %@", [[NSProcessInfo processInfo] processName]);

    // Only run in Roblox
    if (![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.roblox.robloxmobile"]) {
        NSLog(@"[RobloxExecutor] Not Roblox, skipping.");
        return;
    }

    NSLog(@"[RobloxExecutor] Initializing...");

    // Step 1: Bypass anti-cheat checks
    AntiCheatBypass();

    // Step 2: Find and hook the Lua VM
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // Wait for Roblox to fully initialize its Lua VM
        HookLuaVM();

        // Step 3: Set up the executor UI (button to open menu)
        SetupExecutorUI();
    });
}
