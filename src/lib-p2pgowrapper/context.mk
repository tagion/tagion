ifeq ($(OS),Darwin)
# We need these flags on Darwin (possibly only on arm64 macOS)
# because when libp2p-go compiles, it can't find required dependencies.
# This solution was found on StackOverflow
LDCFLAGS += -L-framework -LCoreFoundation -L-framework -LSecurity
endif

p2p-go-wrapper.ctx: wrap-p2p-go-wrapper