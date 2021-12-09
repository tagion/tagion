DEPS += lib-crypto
DEPS += lib-communication
DEPS += lib-services
DEPS += lib-gossip
DEPS += lib-p2pgowrapper

PROGRAM := libdart

$(PROGRAM).configure: SOURCE := tagion/**/*.d