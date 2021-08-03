ifeq ($(OS),Darwin)
LDCFLAGS += -L-framework -LCoreFoundation -L-framework -LSecurity
endif

ctx/lib/p2p: ctx/wrap/p2p