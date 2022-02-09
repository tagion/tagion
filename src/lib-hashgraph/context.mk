DEPS += lib-basic
DEPS += lib-hibon
DEPS += lib-utils
DEPS += lib-crypto
DEPS += lib-communication
DEPS += lib-gossip

PROGRAM := libhashgraph

$(PROGRAM).configure: SOURCE := tagion/**/*.d

$(DBIN)/$(PROGRAM).test: $(DTMP)/libsecp256k1.a
$(DBIN)/$(PROGRAM).test: $(DTMP)/libssl.a
$(DBIN)/$(PROGRAM).test: $(DTMP)/libcrypto.a
$(DBIN)/$(PROGRAM).test: $(DTMP)/libp2pgowrapper.a