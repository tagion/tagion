DEPS += lib-basic
DEPS += lib-hibon
DEPS += lib-utils
DEPS += lib-crypto
DEPS += lib-communication
DEPS += lib-gossip

libhashgraph.configure: SOURCE := tagion/**/*.d

$(DBIN)/libhashgraph.test: $(DTMP)/libsecp256k1.a
$(DBIN)/libhashgraph.test: $(DTMP)/libssl.a
$(DBIN)/libhashgraph.test: $(DTMP)/libcrypto.a
$(DBIN)/libhashgraph.test: $(DTMP)/libp2pgowrapper.a