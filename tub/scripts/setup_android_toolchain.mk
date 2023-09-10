# tools directory
TOOLS:=tools

TARGET_ARCH:=aarch64
ifeq ($(TARGET_ARCH),x86_64)
# There is no distribution for android x86, however the 64-bit libs are included with aarch64 and 32-bit with armv7a
LDC_TARGET:=ldc2-1.29.0-android-aarch64
else
LDC_TARGET:=ldc2-1.29.0-android-$(TARGET_ARCH)
endif
LDC_HOST:=ldc2-1.29.0-linux-x86_64
LDC_HOST_TAR:=$(LDC_HOST).tar.xz
LDC_TARGET_TAR:=$(LDC_TARGET).tar.xz

ANDROID_NDK:=android-ndk-r21b
ANDROID_NDK_ZIP:=$(ANDROID_NDK)-linux-x86_64.zip

ANDROID_CMAKE_ZIP:=cmake-3.10.2-linux-x86_64.zip
ANDROID_CMAKE:=android-cmake

install: $(TOOLS)/.way
install: $(LDC_TARGET) $(ANDROID_NDK) $(LDC_HOST) $(ANDROID_CMAKE)

$(TOOLS)/.way:
	mkdir -p $(TOOLS)
	touch $(TOOLS)/.way

$(TOOLS)/$(LDC_HOST)/.done:
	cd $(TOOLS); wget https://github.com/ldc-developers/ldc/releases/download/v1.29.0/${LDC_HOST_TAR} -O ${LDC_HOST_TAR}
	cd $(TOOLS); tar xf $(LDC_HOST_TAR)
	touch $@

$(TOOLS)/$(LDC_HOST)/etc/ldc2.conf: tub/ldc2.conf
	cp tub/ldc2.conf $(TOOLS)/$(LDC_HOST)/etc/ldc2.conf

$(LDC_HOST): $(TOOLS)/$(LDC_HOST)/.done
$(LDC_HOST): $(TOOLS)/$(LDC_HOST)/etc/ldc2.conf

$(TOOLS)/$(LDC_TARGET)/.done:
	cd $(TOOLS); wget https://github.com/ldc-developers/ldc/releases/download/v1.29.0/${LDC_TARGET_TAR} -O ${LDC_TARGET_TAR}
	cd $(TOOLS); tar xf $(LDC_TARGET_TAR)
	touch $@

$(LDC_TARGET): $(TOOLS)/$(LDC_TARGET)/.done

$(TOOLS)/$(ANDROID_NDK)/.done:
	cd $(TOOLS); wget https://dl.google.com/android/repository/${ANDROID_NDK_ZIP} -O ${ANDROID_NDK_ZIP}
	cd $(TOOLS); unzip $(ANDROID_NDK_ZIP)
	touch $@

$(ANDROID_NDK): $(TOOLS)/$(ANDROID_NDK)/.done

$(TOOLS)/$(ANDROID_CMAKE)/.done:
	cd $(TOOLS); wget https://dl.google.com/android/repository/${ANDROID_CMAKE_ZIP} -O ${ANDROID_CMAKE_ZIP}
	cd $(TOOLS); unzip $(ANDROID_CMAKE_ZIP) -d $(ANDROID_CMAKE)
	touch $@

$(ANDROID_CMAKE): $(TOOLS)/$(ANDROID_CMAKE)/.done

clean:
	$(RM) -vr $(TOOLS)

.PHONE: clean
