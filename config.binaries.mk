export GODEBUG=cgocheck=0

ifdef WOLFSSL
SSLIMPLEMENTATION=$(LIBWOLFSSL)
else
SSLIMPLEMENTATION=$(LIBOPENSSL)
NO_WOLFSSL=-a -not -path "*/wolfssl/*"
endif

NO_UNITDATA=-a -not -path "*/unitdata/*"
EXCLUDED_DIRS+=-a -not -path "*/lib-betterc/*"
EXCLUDED_DIRS+=-a -not -path "*/tests/*"

LIB_DFILES:=${shell find $(DSRC) -name "*.d" -a -path "*/lib-*" $(EXCLUDED_DIRS) $(NO_UNITDATA) }


BIN_DEPS=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-$1/*" $(EXCLUDED_DIRS) $(NO_UNITDATA) $(NO_WOLFSSL) }


#
# Targets for all binaries
#

#
# Core program
#
target-tagionwave: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
${call DO_BIN,tagionwave,$(LIB_DFILES) ${call BIN_DEPS,wave}}

#
# HiBON utility
#
# FIXME(CBR) should be remove when ddeps works correctly
target-hibonutil: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
target-hibonutil: DFILES+=${call BIN_DEPS,hibonutil}
${call DO_BIN,hibonutil,tagion}


#
# DART utility
#
# FIXME(CBR) should be remove when ddeps works correctly
target-dartutil: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
target-dartutil: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-dartutil/*" -a -not -path "*/unitdata/*" $(NO_WOLFSSL) }
target-dartutil: DFILES+=${call BIN_DEPS,dartutil}
${call DO_BIN,dartutil,tagion}

#
# DART utility
#
# FIXME(CBR) should be remove when ddeps works correctly
target-blockutil: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
#target-blockutil: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-blockutil/*" -a -not -path "*/unitdata/*" $(NO_WOLFSSL) }
target-blockutil: DFILES+=${call BIN_DEPS,blockutil}
${call DO_BIN,blockutil,tagion}

#
# WASM utility
#
# FIXME(CBR) should be remove when ddeps works correctly
target-wasmutil: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
#target-wasmutil: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-wasmutil/*" -a -not -path "*/unitdata/*" $(NO_WOLFSSL) }
target-wasmutil: DFILES+=${call BIN_DEPS,wasmutil}
${call DO_BIN,wasmutil,}

#
# WASM utility
#
# FIXME(CBR) should be remove when ddeps works correctly
target-tagionwallet: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
#target-tagionwallet: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-wallet/*" -a -not -path "*/unitdata/*" $(NO_WOLFSSL) }
target-tagionwallet: DFILES+=${call BIN_DEPS,wallet}
${call DO_BIN,tagionwallet,}

wallet: target-tagionwallet

#
# Subscription utility
#
target-tagionsubscription: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
target-tagionsubscription: DFILES+=${call BIN_DEPS,subscription}
${call DO_BIN,tagionsubscription,}

#
# Recorderchain utility
#
target-recorderchain: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
target-recorderchain: DFILES+=${call BIN_DEPS,recorderchain}
${call DO_BIN,recorderchain}

#
# Boot utility
#
# fixme(cbr): When ddeps.mk work those libs are not needed
target-tagionboot: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
target-tagionboot: DFILES+=${call BIN_DEPS,boot}
${call DO_BIN,tagionboot,tagion}

#
# Profile view
#
# fixme(cbr): When ddeps.mk work those libs are not needed
target-tprofview: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
target-tprofview: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-tprofview/*" -a -not -path "*/unitdata/*" -a -not -path "*/lib-betterc/*" $(NO_WOLFSSL) }

#
# Hashgraph view
#
# fixme(cbr): When ddeps.mk work those libs are not needed
target-graphview: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-graphview/*" -a -not -path "*/unitdata/*" -a -not -path "*/lib-betterc/*" $(NO_WOLFSSL) }

#
# Tagion onetool
#
TAGION_TOOLS+=wave
TAGION_TOOLS+=dartutil
TAGION_TOOLS+=blockutil
TAGION_TOOLS+=hibonutil
TAGION_TOOLS+=wallet
TAGION_TOOLS+=tprofview
TAGION_TOOLS+=boot
TAGION_TOOLS+=tools
TAGION_TOOLS+=graphview
TAGION_TOOLS+=recorderchain

TAGION_BINS=$(foreach tools,$(TAGION_TOOLS), ${call BIN_DEPS,$(tools)} )


test32:
	@echo ${call BIN_DEPS,wave}

test34:
	@echo $(TAGION_BINS)





test33:
	@echo $(LIB_DFILES)


target-tagion: DFLAGS+=$(DVERSION)=ONETOOL
target-tagion: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
${call DO_BIN,tagion,$(LIB_DFILES) $(TAGION_BINS)}


#
# Binary of BBD generator tool
#
target-collider: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
#target-collider: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-collider/*" -a -not -path "*/unitdata/*" $(NO_WOLFSSL) }
${call DO_BIN,collider,$(LIB_DFILES) ${call BIN_DEPS,collider}}

target-libtagion: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
target-libtagion: DLIBTYPE?=$(DSTATICLIB)
target-libtagion: DFLAGS+=$(DLIBTYPE)
target-libtagion: DFILES:=${shell find $(DSRC) -name "*.d" -a -path "*/src/lib-*" -a -not -path "*/unitdata/*" -a -not -path "*/tests/*" -a -not -path "*/lib-betterc/*" $(NO_WOLFSSL) }
${call DO_BIN,libtagion,}

