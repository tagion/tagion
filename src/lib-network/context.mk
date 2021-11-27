DEPS += lib-options
DEPS += lib-hibon
DEPS += lib-communication
DEPS += lib-crypto
DEPS += lib-services
DEPS += lib-hashgraph
DEPS += lib-p2pgowrapper

libnetwork.configure: SOURCE := tagion/**/*.d

$(DBIN)/libnetwork.test: $(DIR_BUILD_WRAPS)/secp256k1/lib/libsecp256k1.a
$(DBIN)/libnetwork.test: $(DIR_BUILD_WRAPS)/openssl/lib/libcrypto.a
$(DBIN)/libnetwork.test: $(DIR_BUILD_WRAPS)/openssl/lib/libssl.a
$(DBIN)/libnetwork.test: $(DIR_BUILD_WRAPS)/p2pgowrapper/lib/libp2pgowrapper.a