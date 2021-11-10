DEPS += lib-dart
DEPS += lib-crypto
DEPS += lib-logger
PROGRAM:=boot

${call config.bin, $(PROGRAM)}: LOOKUP := tagion/*.d

${call bin, $(PROGRAM)}: INFILES += $(DIR_BUILD_WRAPS)/secp256k1/lib/libsecp256k1.a
${call bin, $(PROGRAM)}: INFILES += $(DIR_BUILD_WRAPS)/openssl/lib/libssl.a
${call bin, $(PROGRAM)}: INFILES += $(DIR_BUILD_WRAPS)/openssl/lib/libcrypto.a
${call bin, $(PROGRAM)}: INFILES += $(DIR_BUILD_WRAPS)/p2pgowrapper/lib/libp2pgowrapper.a
