# TODO: Describe the reason behind this flags
ifeq ($(OS),Darwin)
LDCFLAGS += -L-framework -LCoreFoundation -L-framework -LSecurity
endif

ctx/lib/p2p-go-wrapper: ctx/wrap/p2p-go-wrapper