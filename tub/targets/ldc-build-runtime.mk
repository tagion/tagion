
TOOLS_LDC_BIN=$(TOOLS)/$(LDC_NAME)/bin
# LDC_BUILD_RUNTIME:=$(TOOLS_LDC_BIN)/ldc-build-runtime
LDC_BUILD_RUNTIME:=$(shell which ldc-build-runtime)
LDC_BUILD_RUNTIME_TMP:=$(DBUILD)/tmp/druntime/

$(BUILD)/$(ARCH)-linux-android/tmp/druntime/: $(LDC_BUILD_RUNTIME)
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

# $(REPOROOT)/build/$(ARCH)-ios/tmp/druntime/: $(LDC_BUILD_RUNTIME)
# /home/lucas/wrk/tagion/build/aarch64-ios/tmp/druntime/
$(BUILD)/$(ARCH)-ios/tmp/druntime/: $(LDC_BUILD_RUNTIME)
	$(LDC_BUILD_RUNTIME) \
	--buildDir=$(LDC_BUILD_RUNTIME_TMP) \
	--dFlags="-mtriple=$(TRIPLET) -flto=thin" \
	--targetSystem="iOS;Darwin;UNIX" \
	BUILD_LTO_LIBS=ON

druntime: $(LDC_BUILD_RUNTIME_TMP)

env-druntime:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.kvp, LDC_BUILD_RUNTIME, $(LDC_BUILD_RUNTIME)}
	${call log.kvp, LDC_BUILD_RUNTIME_TMP, $(LDC_BUILD_RUNTIME_TMP)}
	${call log.close}


env: env-druntime

help-druntime:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make druntime PLATFORM=<platform>", "Build the runtime for <platform>"}
	${call log.close}

help: help-druntime

.PHONY: env-druntime help-druntime

proper-druntime:
	$(PRECMD)
	$(RM) -r $(LDC_BUILD_RUNTIME_TMP)

.PHONY: proper-druntime
