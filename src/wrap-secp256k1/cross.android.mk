# CONFIGUREFLAGS_SECP256K1 += --enable-ecmult-static-precomputation --enable-experimental
# Note. The asm part does not compile for aarch64
# So it is not enabled.
#--with-asm=arm
CONFIGUREFLAGS_SECP256K1 += --disable-benchmark
