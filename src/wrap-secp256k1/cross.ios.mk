XCODE_ROOT := ${shell xcode-select -print-path}

XCODE_SIMULATOR_SDK = $(XCODE_ROOT)/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator$(IPHONE_SDKVERSION).sdk
XCODE_DEVICE_SDK = $(XCODE_ROOT)/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS$(IPHONE_SDKVERSION).sdk

CROSS_SYSROOT=$(XCODE_SIMULATOR_SDK)

${if $(CROSS_COMPILE),--host=$(MTRIPLE) --target=$(MTRIPLE) --with-sysroot=$(CROSS_SYSROOT)} 

${if $(CROSS_COMPILE),CC=/usr/bin/clang CFLAGS="-arch $(CROSS_ARCH) -fpic -g -Os -pipe -isysroot $(CROSS_SYSROOT) -mios-version-min=12.0"} 