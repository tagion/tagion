#DC?=dmd
export GODEBUG:=cgocheck=0
ONETOOL?=1
DEBUGGER?=ddd
VERBOSE_COMPILER_ERRORS=1
# SECP256K1_DEBUG=1
# USE_SYSTEM_LIBS=1 # Compile with systemdependencies

export TEST_STAGE:=commit
export SEED:=$(shell git rev-parse HEAD)

RELEASE_DFLAGS+=$(DOPT)

ifdef USE_SYSTEM_LIBS
NNG_ENABLE_TLS=1
endif

#
# Set the Digital Signature scheam
# The default is Schnorr can be switch to ECDSA 
# With this devsion flag
#
#DFLAGS+=$(DVERSION)=SECP256K1_ECDSA

ifndef DEBUG_DISABLE
DFLAGS+=$(DDEBUG_SYMBOLS)
endif

DFLAGS+=$(DVERSION)=REDBLACKTREE_SAFE_PROBLEM


# Extra DFLAGS for the testbench 
BDDDFLAGS+=$(DDEBUG_SYMBOLS)
BDDDFLAGS+=$(DEXPORT_DYN)

