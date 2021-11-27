DEPS += lib-utils
DEPS += lib-hashgraph
DEPS += lib-hibon
DEPS += lib-crypto
DEPS += lib-communication
DEPS += lib-gossip
DEPS += lib-p2pgowrapper
DEPS += lib-dart
DEPS += lib-monitor

libservices.configure: SOURCE := tagion/**/*.d tagion/*.d

$(DBIN)/libservices.test: $(DIR_BUILD_WRAPS)/secp256k1/lib/libsecp256k1.a
$(DBIN)/libservices.test: $(DIR_BUILD_WRAPS)/openssl/lib/libssl.a
$(DBIN)/libservices.test: $(DIR_BUILD_WRAPS)/openssl/lib/libcrypto.a
$(DBIN)/libservices.test: $(DIR_BUILD_WRAPS)/p2pgowrapper/lib/libp2pgowrapper.a