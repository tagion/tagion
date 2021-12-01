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

PROGRAM := libmonitor

$(PROGRAM).configure: SOURCE := tagion/**/*.d

$(DBIN)/$(PROGRAM).test: $(DTMP)/libsecp256k1.a
$(DBIN)/$(PROGRAM).test: $(DTMP)/libssl.a
$(DBIN)/$(PROGRAM).test: $(DTMP)/libcrypto.a
$(DBIN)/$(PROGRAM).test: $(DTMP)/libp2pgowrapper.a