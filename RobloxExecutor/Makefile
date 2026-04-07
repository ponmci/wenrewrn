TARGET := iphone:clang:latest:14.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = Roblox

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = RobloxExecutor

RobloxExecutor_FILES = src/Tweak.x src/LuaVMHook.mm src/AntiCheat.mm src/Executor.mm
RobloxExecutor_FRAMEWORKS = UIKit Foundation Security
RobloxExecutor_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
RobloxExecutor_LIBRARIES = substrate
RobloxExecutor_LDFLAGS = -lstdc++

# Frida gadget (embedded)
# If you have FridaGadget.dylib, place it in libs/ and uncomment:
# RobloxExecutor_LIBRARIES += c++
# RobloxExecutor_LDFLAGS += -Llibs -lFridaGadget

include $(THEOS_MAKE_PATH)/tweak.mk

# Debug build
debug:: clean all
	@echo "Build complete. Debug binary at .theos/obj/debug/"
