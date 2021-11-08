ifeq ($(OS),Darwin)
# We need these flags on Darwin (possibly only on arm64 macOS)
# because when libp2p-go compiles, it can't find required dependencies.
# This solution was found on StackOverflow
LDCFLAGS += -L-framework -LCoreFoundation -L-framework -LSecurity
endif

DEPS += wrap-p2pgowrapper

${call config.lib, p2pgowrapper}: wrap-p2pgowrapper
${call config.lib, p2pgowrapper}: LOOKUP := p2p/*.d
${call lib, p2pgowrapper}: LINKFILES := $(DIR_BUILD_WRAPS)/p2pgowrapper/lib/libp2pgowrapper.a