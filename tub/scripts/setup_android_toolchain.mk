.ONESHELL:
# tools directory
TOOLS:=tools


LDC_HOST:=ldc2-1.29.0-linux-x86_64
LDC_TARGET:=ldc2-1.29.0-android-aarch64
LDC_HOST_TAR:=$(LDC_HOST).tar.xz
LDC_TARGET_TAR:=$(LDC_TARGET).tar.xz

ANDROID_NDK:=android-ndk-r21b
ANDROID_NDK_ZIP:=$(ANDROID_NDK)-linux-x86_64.zip

install: $(TOOLS)/.way
install: $(TOOLS)/$(LDC_TARGET) $(TOOLS)/$(ANDROID_NDK) $(TOOLS)/$(LDC_HOST)

$(TOOLS)/.way:
	mkdir -p $(TOOLS)
	touch $(TOOLS)/.way

$(TOOLS)/$(ANDROID_NDK_ZIP):
	cd $(TOOLS)
	wget https://dl.google.com/android/repository/${ANDROID_NDK_ZIP}

$(TOOLS)/$(LDC_TARGET_TAR):
	cd $(TOOLS)
	wget https://github.com/ldc-developers/ldc/releases/download/v1.29.0/${LDC_TARGET_TAR}

$(TOOLS)/$(LDC_HOST_TAR):
	cd $(TOOLS)
	wget https://github.com/ldc-developers/ldc/releases/download/v1.29.0/${LDC_HOST_TAR}

$(TOOLS)/$(LDC_HOST): $(TOOLS)/$(LDC_HOST_TAR)
	cd $(TOOLS)
	tar xf $(LDC_HOST_TAR)
	cd -
	cp tub/ldc2.conf $(TOOLS)/$(LDC_HOST)/etc/

$(TOOLS)/$(LDC_TARGET): $(TOOLS)/$(LDC_TARGET_TAR)
	cd $(TOOLS)
	tar xf $(LDC_TARGET_TAR)

$(TOOLS)/$(ANDROID_NDK): $(TOOLS)/$(ANDROID_NDK_ZIP)
	cd $(TOOLS)
	unzip $(ANDROID_NDK_ZIP)
