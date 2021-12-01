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

$(DBIN)/libmonitor.test: $(DTMP)/libsecp256k1.a
$(DBIN)/libmonitor.test: $(DTMP)/libssl.a
$(DBIN)/libmonitor.test: $(DTMP)/libcrypto.a
$(DBIN)/libmonitor.test: $(DTMP)/libp2pgowrapper.a