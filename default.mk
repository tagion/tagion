#DC?=dmd
export GODEBUG:=cgocheck=0
ONETOOL?=1
DEBUGGER?=ddd
VERBOSE_COMPILER_ERRORS=1
# SECP256K1_DEBUG=1

export TEST_STAGE:=commit
export SEED:=$(shell git rev-parse HEAD)

RELEASE_DFLAGS+=$(DOPT)

# USE_SYSTEM_LIBS=1 # Compile with system libraries (nng & secp256k1-zkp)

# If youre using system libraries they'll most likely be compiled with mbedtls support
# So mbedtls needs to be linked as well, so this need to be enabled
# NNG_ENABLE_TLS=1

ifndef DEBUG_DISABLE
DFLAGS+=$(DDEBUG_SYMBOLS)
endif

DFLAGS+=$(DVERSION)=REDBLACKTREE_SAFE_PROBLEM
DFLAGS+=$(DVERSION)=NET_HACK
# DFLAGS+=$(DVERSION)=NEW_REPLICATOR

# Extra DFLAGS for the testbench 
BDDDFLAGS+=$(DDEBUG_SYMBOLS)
BDDDFLAGS+=$(DEXPORT_DYN)

INSTALL?=$(HOME)/bin
