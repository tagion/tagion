
LDC_NAME=ldc2-1.29.0-beta1-$(GETHOSTOS)-$(GETARCH)
LDC_TAR_NAME=$(LDC_NAME).tar.xz
LDC_URL=https://github.com/ldc-developers/ldc/releases/download/v1.29.0-beta1/$(LDC_TAR_NAME)
LDC_TAR=$(TOOLS)/$(LDC_TAR_NAME)
TOOLS_LDC_BIN=$(TOOLS)/$(LDC_NAME)/bin
LDC_BUILD_RUNTIME:=$(TOOLS_LDC_BIN)/ldc-build-runtime
LDC_BUILD_RUNTIME_TMP:=$(DBUILD)/ldc-build-runtime.tmp
#https://github.com/ldc-developers/ldc/releases/download/v1.29.0-beta1/ldc2-1.29.0-beta1-linux-x86_64.tar.xz

$(LDC_TAR): $(TOOLS)/.way
	$(PRECMD)
	echo $(LDC_TAR)
	$(CD) $(TOOLS); wget $(LDC_URL)
	$(TOUCH) $@

$(TOOLS_LDC_BIN): $(LDC_TAR)
	$(PRECMD)
	$(CD) $(TOOLS); tar -xJvf $<
	$(TOUCH) $@

druntime: $(LDC_BUILD_RUNTIME_TMP)

$(LDC_BUILD_RUNTIME_TMP): $(TOOLS_LDC_BIN)
	$(LDC_BUILD_RUNTIME) \
	--buildDir=$(LDC_BUILD_RUNTIME_TMP) \
	--dFlags="-mtriple=$(TRIPLET) -flto=thin" \
	--targetSystem="Android;Linux;UNIX" \
	CMAKE_TOOLCHAIN_FILE="$(ANDROID_CMAKE)" \
	ANDROID_ABI=$(ANDROID_ABI) \
	ANDROID_NATIVE_API_LEVEL=$(ANDROID_API) \
	ANDROID_PLATFORM=android-$(ANDROID_API) \
	MAKE_SYSTEM_VERSION=$(ANDROID_API) \
	BUILD_LTO_LIBS=ON

druntime-bin: $(TOOLS_LDC_BIN)

druntime-tar: $(LDC_TAR)

env-druntime:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.kvp, LDC_TAR_NAME, $(LDC_TAR_NAME)}
	${call log.kvp, LDC_NAME, $(LDC_NAME)}
	${call log.kvp, LDC_TAR, $(LDC_TAR)}
	${call log.kvp, LDC_URL, $(LDC_URL)}
	${call log.kvp, TOOLS_LCD_BIN, $(TOOLS_LDC_BIN)}
	${call log.kvp, LDC_BUILD_RUNTIME, $(LDC_BUILD_RUNTIME)}
	${call log.kvp, LDC_BUILD_RUNTIME_TMP, $(LDC_BUILD_RUNTIME_TMP)}
	${call log.close}


env: env-druntime

help-druntime:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make druntime-bin", "Installs ldc2 compiler and runtime"}
	${call log.help, "make druntime-tar", "Downloads the tar file for ldc2 compiler"}
	${call log.close}

help: help-druntime


.PHONY: env-druntime help-druntime
