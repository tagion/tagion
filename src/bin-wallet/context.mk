DEPS += lib-wallet
DEPS += lib-communication
DEPS += lib-network
DEPS += lib-crypto
PROGRAM:=tagionwallet

$(DBIN)/$(PROGRAM): $(DTMP)/libsecp256k1.a
$(DBIN)/$(PROGRAM): $(DTMP)/libssl.a
$(DBIN)/$(PROGRAM): $(DTMP)/libcrypto.a

$(PROGRAM).configure: SOURCE := tagion/*.d
