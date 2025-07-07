# tools director
TOOLS:=$(abspath $(REPOROOT)/tools)
LDC_VERSION:=1.37.0
LDC_HOST:=ldc2-${LDC_VERSION}-linux-x86_64
LDC_HOST_TAR:=$(LDC_HOST).tar.xz
LDC_WASI_BIN:=$(TOOLS)/$(LDC_HOST)/bin
LDC_WASI:=$(LDC_WASI_BIN)/ldc2
export DC=$(LDC_WASI)
#ANDROID_NDK:=android-ndk-r21b
#ANDROID_NDK_ZIP:=$(ANDROID_NDK)-linux-x86_64.zip

#ANDROID_CMAKE_ZIP:=cmake-3.10.2-linux-x86_64.zip
#ANDROID_CMAKE:=android-cmake

install-wasi-wasm-toolchain: $(LDC_HOST) 
.PHONY: install-wasi-wasm-toolchain

$(TOOLS)/.way:
	mkdir -p $(TOOLS)
	touch $(TOOLS)/.way

$(TOOLS)/$(LDC_HOST)/etc/ldc2.conf: $(TOOLS)/$(LDC_HOST)/.done tub/ldc2.conf
	mv $(TOOLS)/$(LDC_HOST)/etc/ldc2.conf $(TOOLS)/$(LDC_HOST)/etc/ldc2.conf.orig || true
	cp tub/ldc2.conf $(TOOLS)/$(LDC_HOST)/etc/ldc2.conf

$(LDC_HOST): $(TOOLS)/$(LDC_HOST)/.done
$(LDC_HOST): $(TOOLS)/$(LDC_HOST)/etc/ldc2.conf
.PHONY: $(LDC_HOST)

$(TOOLS)/$(LDC_HOST)/.done: $(TOOLS)/.way
	cd $(TOOLS)
	wget https://github.com/ldc-developers/ldc/releases/download/v${LDC_VERSION}/${LDC_HOST_TAR} -O ${LDC_HOST_TAR}
	tar xf $(LDC_HOST_TAR)
	touch $@

clean-tools:
	$(RM) -vr $(TOOLS)

.PHONY: clean-tools

proper: clean-tools
