DEPS += lib-utils
DEPS += lib-hashgraph
DEPS += lib-hibon
DEPS += lib-crypto
DEPS += lib-communication
DEPS += lib-gossip
DEPS += lib-p2pgowrapper
DEPS += lib-dart
DEPS += lib-monitor

PROGRAM := libservices

$(PROGRAM).configure: SOURCE := tagion/services/*.d tagion/*.d

$(DBIN)/$(PROGRAM).test: $(DTMP)/libsecp256k1.a
$(DBIN)/$(PROGRAM).test: $(DTMP)/libssl.a
$(DBIN)/$(PROGRAM).test: $(DTMP)/libcrypto.a
$(DBIN)/$(PROGRAM).test: $(DTMP)/libp2pgowrapper.a