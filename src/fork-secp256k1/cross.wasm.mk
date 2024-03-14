# CONFIGUREFLAGS_SECP256K1 += --enable-ecmult-static-precomputation --enable-experimental
# Note. The asm part does not compile for aarch64
# So it is not enabled.
#--with-asm=arm
#CONFIGUREFLAGS_SECP256K1 += CFLAGS="--target=$(TRIPLET) -flto -DVERIFY=1 -DUSE_FORCE_WIDEMUL_INT128_STRUCT=1"
CONFIGUREFLAGS_SECP256K1 += CFLAGS="--target=$(TRIPLET) -flto -DVERIFY=1 -DUSE_FORCE_WIDEMUL_INT128_STRUCT=1"
CONFIGUREFLAGS_SECP256K1 += --disable-benchmark
