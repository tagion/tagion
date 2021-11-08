DEPS += lib-crypto
DEPS += lib-communication
DEPS += lib-services
DEPS += lib-gossip
DEPS += lib-p2pgowrapper

${call config.lib, dart}: LOOKUP := tagion/**/*.d