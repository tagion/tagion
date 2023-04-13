#DC?=dmd
export GODEBUG=cgocheck=0
WOLFSSL?=1
OLD?=1
ONETOOL?=1
DEBUGGER?=ddd
export TEST_STAGE?=commit
export SEED?=$(shell git rev-parse HEAD)

DFLAGS+=$(DVERSION)=REDBLACKTREE_SAFE_PROBLEM
DFLAGS+=$(DVERSION)=SYNC_BLOCKFILE_WORKING #this is the version for debugging the recycler segments has overlaps. recorder: a < a

# Extra DFLAGS for the testbench 
BDDDFLAGS+=$(DDEBUG_SYMBOLS)
BDDDFLAGS+=$(DEXPORT_DYN)

ifdef WOLFSSL
DFLAGS+=$(DVERSION)=TINY_AES
DFLAGS+=$(DVERSION)=WOLFSSL
SSLIMPLEMENTATION=$(LIBWOLFSSL)
else
SSLIMPLEMENTATION=$(LIBOPENSSL)
NO_WOLFSSL=-a -not -path "*/wolfssl/*"
endif

ifdef OLD
DFLAGS+=$(DVERSION)=OLD_TRANSACTION
endif

