CONFIGUREFLAGS_SECP256K1 += CFLAGS="-arch $(CROSS_ARCH) -fpic -g -Os -pipe -isysroot $(CROSS_SYSROOT) -mios-version-min=12.0"
