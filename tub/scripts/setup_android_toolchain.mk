# tools directory
TOOLS:=$(abspath $(REPOROOT)/tools)

LDC_VERSION:=1.37.0
LDC_HOST:=ldc2-${LDC_VERSION}-linux-x86_64
LDC_HOST_TAR:=$(LDC_HOST).tar.xz

ANDROID_NDK:=android-ndk-r21b
ANDROID_NDK_ZIP:=$(ANDROID_NDK)-linux-x86_64.zip

ANDROID_CMAKE_ZIP:=cmake-3.10.2-linux-x86_64.zip
ANDROID_CMAKE:=android-cmake

install-android-toolchain: $(LDC_HOST) $(ANDROID_NDK) $(ANDROID_CMAKE)
.PHONY: install-android-toolchain

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
	wget https://github.com/ldc-developers/ldc/releases/download/v${LDC_VERSION}/ldc2-${LDC_VERSION}-android-aarch64.tar.xz -O ldc2-${LDC_VERSION}-android-aarch64.tar.xz
	wget https://github.com/ldc-developers/ldc/releases/download/v${LDC_VERSION}/ldc2-${LDC_VERSION}-android-armv7a.tar.xz -O ldc2-${LDC_VERSION}-android-armv7a.tar.xz
	tar xf ldc2-${LDC_VERSION}-android-aarch64.tar.xz
	tar xf ldc2-${LDC_VERSION}-android-armv7a.tar.xz
	mkdir -p $(LDC_HOST)/android-aarch64/ $(LDC_HOST)/android-x86_64/ $(LDC_HOST)/android-armv7a/
	cp -r ldc2-${LDC_VERSION}-android-aarch64/lib-x86_64 $(LDC_HOST)/android-x86_64/lib
	cp -r ldc2-${LDC_VERSION}-android-aarch64/lib $(LDC_HOST)/android-aarch64/
	cp -r ldc2-${LDC_VERSION}-android-armv7a/lib $(LDC_HOST)/android-armv7a/
	cd -
	touch $@

$(TOOLS)/$(ANDROID_NDK)/.done: $(TOOLS)/.way 
	cd $(TOOLS)
	wget https://dl.google.com/android/repository/${ANDROID_NDK_ZIP} -O ${ANDROID_NDK_ZIP}
	unzip $(ANDROID_NDK_ZIP)
	cd -
	touch $@

$(ANDROID_NDK): $(TOOLS)/$(ANDROID_NDK)/.done

$(TOOLS)/$(ANDROID_CMAKE)/.done: $(TOOLS)/.way  
	cd $(TOOLS)
	wget https://dl.google.com/android/repository/${ANDROID_CMAKE_ZIP} -O ${ANDROID_CMAKE_ZIP}
	unzip $(ANDROID_CMAKE_ZIP) -d $(ANDROID_CMAKE)
	cd -
	touch $@

$(ANDROID_CMAKE): $(TOOLS)/$(ANDROID_CMAKE)/.done

clean-tools:
	$(RM) -vr $(TOOLS)

.PHONY: clean-tools

proper: clean-tools
