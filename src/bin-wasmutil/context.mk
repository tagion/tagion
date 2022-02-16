DEPS += lib-basic
DEPS += lib-wasm
DEPS += lib-hibon

PROGRAM := tagionwasmutil

$(PROGRAM).configure: SOURCE := tagion/*.d

$(DBIN)/$(PROGRAM): $(DTMP)/libsecp256k1.a
$(DBIN)/$(PROGRAM): $(DTMP)/libssl.a
$(DBIN)/$(PROGRAM): $(DTMP)/libcrypto.a