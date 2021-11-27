DEPS += lib-basic
DEPS += lib-hibon
DEPS += lib-utils
DEPS += lib-crypto
DEPS += lib-communication
DEPS += lib-gossip

libhashgraph.configure: SOURCE := tagion/**/*.d

$(DBIN)/libhashgraph.test: $(DIR_BUILD_WRAPS)/secp256k1/lib/libsecp256k1.a
$(DBIN)/libhashgraph.test: $(DIR_BUILD_WRAPS)/openssl/lib/libssl.a
$(DBIN)/libhashgraph.test: $(DIR_BUILD_WRAPS)/openssl/lib/libcrypto.a
$(DBIN)/libhashgraph.test: $(DIR_BUILD_WRAPS)/p2pgowrapper/lib/libp2pgowrapper.a