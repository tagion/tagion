

${if $(CROSS_COMPILE),--host=$(MTRIPLE) --target=$(MTRIPLE) --with-sysroot=$(CROSS_SYSROOT)} 

${if $(CROSS_COMPILE),CC=/usr/bin/clang CFLAGS="-arch $(CROSS_ARCH) -fpic -g -Os -pipe -isysroot $(CROSS_SYSROOT) -mios-version-min=12.0"} 