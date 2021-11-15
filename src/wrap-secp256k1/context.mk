REPO_SECP256K1 ?= git@github.com:tagion/fork-secp256k1.git
VERSION_SECP256k1 := ea5e8a9c47f1d435e8f66913eb7f1293b85b43f9

DIR_SECP256K1 := $(DIR_BUILD_WRAPS)/secp256k1

DIR_SECP256K1_PREFIX := $(DIR_SECP256K1)/lib
DIR_SECP256K1_SRC := $(DIR_SECP256K1)/src

wrap-secp256k1: $(DIR_SECP256K1_PREFIX)/libsecp256k1.a
	@

clean-wrap-secp256k1:
	${call unit.dep.wrap-secp256k1}
	${call rm.dir, $(DIR_SECP256K1_SRC)}

# TRY Specifying toolchain

XCODE_ROOT := ${shell xcode-select -print-path}

XCODE_SIMULATOR_SDK = $(XCODE_ROOT)/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator$(IPHONE_SDKVERSION).sdk
XCODE_DEVICE_SDK = $(XCODE_ROOT)/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS$(IPHONE_SDKVERSION).sdk

CROSS_SYSROOT=$(XCODE_SIMULATOR_SDK)

$(DIR_SECP256K1_PREFIX)/%.a: $(DIR_SECP256K1)/.way
	$(PRECMD)git clone --depth 1 $(REPO_SECP256K1) $(DIR_SECP256K1_SRC) 2> /dev/null || true
	$(PRECMD)git -C $(DIR_SECP256K1_SRC) fetch --depth 1 $(DIR_SECP256K1_SRC) $(VERSION_SECP256k1) &> /dev/null || true
	$(PRECMD)cd $(DIR_SECP256K1_SRC); ./autogen.sh
	$(PRECMD)cd $(DIR_SECP256K1_SRC); ./configure ${if $(CROSS_COMPILE),--host=$(MTRIPLE) --target=$(MTRIPLE) --with-sysroot=$(CROSS_SYSROOT)} --enable-shared=no CRYPTO_LIBS=$(DIR_OPENSSL)/lib/ CRYPTO_CFLAGS=$(DIR_OPENSSL)/include/ ${if $(CROSS_COMPILE),CC=/usr/bin/clang CFLAGS="-arch $(CROSS_ARCH) -fpic -g -Os -pipe -isysroot $(CROSS_SYSROOT) -mios-version-min=12.0"}
	$(PRECMD)cd $(DIR_SECP256K1_SRC); make clean
	$(PRECMD)cd $(DIR_SECP256K1_SRC); make $(MAKE_PARALLEL)
	$(PRECMD)cd $(DIR_SECP256K1_SRC); mv .libs ../lib
