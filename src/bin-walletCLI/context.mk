DEPS += lib-basic
DEPS += lib-hibon
DEPS += lib-crypto
DEPS += lib-funnel
DEPS += lib-communication
DEPS += lib-p2pgowrapper

PROGRAM := tagionwalletCLI

$(PROGRAM).configure: SOURCE := tagion/tagionwalletCLI.d

# $(DBIN)/$(PROGRAM): DCFLAGS += -unittest
$(DBIN)/$(PROGRAM): $(DTMP)/libsecp256k1.a
$(DBIN)/$(PROGRAM): $(DTMP)/libssl.a
$(DBIN)/$(PROGRAM): $(DTMP)/libcrypto.a
$(DBIN)/$(PROGRAM): $(DTMP)/libp2pgowrapper.a