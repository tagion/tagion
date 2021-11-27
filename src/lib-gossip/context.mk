DEPS += lib-hibon
DEPS += lib-utils
DEPS += lib-crypto
DEPS += lib-hashgraph
DEPS += lib-dart
DEPS += lib-communication
DEPS += lib-p2pgowrapper

libgossip.configure: SOURCE := tagion/**/*.d

$(DBIN)/libgossip.test: $(DIR_BUILD_WRAPS)/secp256k1/lib/libsecp256k1.a
$(DBIN)/libgossip.test: $(DIR_BUILD_WRAPS)/openssl/lib/libssl.a
$(DBIN)/libgossip.test: $(DIR_BUILD_WRAPS)/openssl/lib/libcrypto.a
$(DBIN)/libgossip.test: $(DIR_BUILD_WRAPS)/p2pgowrapper/lib/libp2pgowrapper.a