# IOS_PLATFORMS           += arm64-apple-ios-simulator
# IOS_PLATFORMS           += arm64-apple-ios
# IOS_PLATFORMS           += x86_64-apple-ios-simulator
# IOS_PLATFORMS           += x86_64-apple-ios

# tools directory
TOOLS:=$(abspath $(REPOROOT)/tools)

LDC_VERSION:=1.37.0

# Host. This is the compiler that will be used to compile the code.
LDC_HOST:=ldc2-${LDC_VERSION}-osx-universal
LDC_HOST_TAR:=$(LDC_HOST).tar.xz

# Target. This is the compiler that will be used to compile the code for the target platform.
# LDC_TARGET:=ldc2-${LDC_VERSION}$(TARGET_ARCH)-apple-ios

install-ios-toolchain: $(TOOLS)/.way
install-ios-toolchain: $(LDC_HOST)

$(TOOLS)/.way:
	mkdir -p $(TOOLS)
	touch $(TOOLS)/.way

$(TOOLS)/$(LDC_HOST)/.done:
	cd $(TOOLS)
	wget https://github.com/ldc-developers/ldc/releases/download/v${LDC_VERSION}/${LDC_HOST_TAR} -O ${LDC_HOST_TAR}
	tar xf $(LDC_HOST_TAR)
	cd -
	touch $@

$(TOOLS)/$(LDC_HOST)/etc/ldc2.conf: tub/ldc2.conf
	cp tub/ldc2.conf $(TOOLS)/$(LDC_HOST)/etc/ldc2.conf

$(LDC_HOST): $(TOOLS)/$(LDC_HOST)/.done
$(LDC_HOST): $(TOOLS)/$(LDC_HOST)/etc/ldc2.conf

clean-tools:
	$(RM) -vr $(TOOLS)

.PHONY: clean-tools

proper: clean-tools