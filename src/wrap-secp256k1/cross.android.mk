# CONFIGUREFLAGS_SECP256K1 += --enable-ecmult-static-precomputation --enable-experimental --with-asm=arm
# export AR=$(CROSS_TOOLCHAIN)/llvm-ar
# export CC=$(CROSS_TOOLCHAIN)/$(MTRIPLE)$(CROSS_ANDROID_API)-clang
# export AS=$(CROSS_TOOLCHAIN)/$(MTRIPLE)$(CROSS_ANDROID_API)-clang
# export CXX="$(CROSS_TOOLCHAIN)/$(MTRIPLE)$(CROSS_ANDROID_API)-clang++"
# export LD=$(CROSS_TOOLCHAIN)/ld
# export RANLIB=$(CROSS_TOOLCHAIN)/llvm-ranlib
# export STRIP=$(CROSS_TOOLCHAIN)/llvm-strip
# # export CFLAGS="-mthumb -march=$(CROSS_ARCH)"
# # export CCASFLAGS="-Wa,-mthumb -Wa,-march=$(CROSS_ARCH)"