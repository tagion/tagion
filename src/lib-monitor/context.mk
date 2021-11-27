DEPS += lib-basic
DEPS += lib-hashgraph
DEPS += lib-hibon
DEPS += lib-crypto
DEPS += lib-communication
DEPS += lib-gossip
DEPS += lib-dart
DEPS += lib-network
DEPS += lib-funnel
DEPS += lib-p2pgowrapper

libmonitor.configure: SOURCE := tagion/**/*.d

$(DBIN)/libmonitor.test: $(DIR_BUILD_WRAPS)/secp256k1/lib/libsecp256k1.a
$(DBIN)/libmonitor.test: $(DIR_BUILD_WRAPS)/openssl/lib/libssl.a
$(DBIN)/libmonitor.test: $(DIR_BUILD_WRAPS)/openssl/lib/libcrypto.a
$(DBIN)/libmonitor.test: $(DIR_BUILD_WRAPS)/p2pgowrapper/lib/libp2pgowrapper.a