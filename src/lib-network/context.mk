DEPS += lib-options
DEPS += lib-hibon
DEPS += lib-communication
DEPS += lib-crypto
DEPS += lib-services
DEPS += lib-hashgraph
DEPS += lib-p2pgowrapper

PROGRAM := libnetwork

$(PROGRAM).configure: SOURCE := tagion/**/*.d

$(DBIN)/$(PROGRAM).test: $(DTMP)/libsecp256k1.a
$(DBIN)/$(PROGRAM).test: $(DTMP)/libssl.a
$(DBIN)/$(PROGRAM).test: $(DTMP)/libcrypto.a
$(DBIN)/$(PROGRAM).test: $(DTMP)/libp2pgowrapper.a