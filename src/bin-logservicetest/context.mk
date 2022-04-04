DEPS += lib-services
DEPS += lib-network
DEPS += lib-utils
DEPS += lib-communication
DEPS += lib-funnel

PROGRAM := tagionlogservicetest

$(PROGRAM).configure: SOURCE := tagion/*.d

$(DBIN)/$(PROGRAM): DCFLAGS += -D
$(DBIN)/$(PROGRAM): $(DTMP)/libssl.a
$(DBIN)/$(PROGRAM): $(DTMP)/libcrypto.a
$(DBIN)/$(PROGRAM): $(DTMP)/libp2pgowrapper.a