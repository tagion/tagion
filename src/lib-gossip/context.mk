DEPS += lib-hibon
DEPS += lib-utils
DEPS += lib-crypto
DEPS += lib-hashgraph
DEPS += lib-dart
DEPS += lib-communication
DEPS += lib-p2pgowrapper

libgossip.configure: SOURCE := tagion/**/*.d

$(DBIN)/libgossip.test: $(DTMP)/libsecp256k1.a
$(DBIN)/libgossip.test: $(DTMP)/libssl.a
$(DBIN)/libgossip.test: $(DTMP)/libcrypto.a
$(DBIN)/libgossip.test: $(DTMP)/libp2pgowrapper.a