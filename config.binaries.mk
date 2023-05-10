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
LIB_BETTERC:=${shell find $(DSRC) -name "*.d" -a -path "*/lib-betterc/*" -a -not -path "*/tests/*" $(NO_UNITDATA) }


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
target-hibonutil: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
${call DO_BIN,hibonutil,$(LIB_DFILES) ${call BIN_DEPS,hibonutil}}


#
# DART utility
#
target-dartutil: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
${call DO_BIN,dartutil,$(LIB_DFILES) ${call BIN_DEPS,dartutil},tagion}

#
# DART utility
#
target-blockutil: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
${call DO_BIN,blockutil,$(LIB_DFILES) ${call BIN_DEPS,blockutil},tagion}

#
# WASM utility
#
target-wasmutil: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
${call DO_BIN,wasmutil,$(LIB_DFILES) ${call BIN_DEPS,wasmutil},tagion}

#
# WASM utility
#
target-tagionwallet: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
${call DO_BIN,tagionwallet,$(LIB_DFILES) ${call BIN_DEPS,tagionwallet},tagion}

wallet: target-tagionwallet

#
# Subscription utility
#
target-tagionsubscription: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
${call DO_BIN,subscription,$(LIB_DFILES) ${call BIN_DEPS,subsciption}}

#
# Recorderchain utility
#
target-recorderchain: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
${call DO_BIN,recorderchain,$(LIB_DFILES) ${call BIN_DEPS,recorderchain},tagion}

#
# Boot utility
#
# fixme(cbr): When ddeps.mk work those libs are not needed
target-tagionboot: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
${call DO_BIN,tagionboot,$(LIB_DFILES) ${call BIN_DEPS,boot},tagion}

#
# Profile view
#
# fixme(cbr): When ddeps.mk work those libs are not needed
target-tprofview: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
${call DO_BIN,tprofview,$(LIB_DFILES) ${call BIN_DEPS,tprofview},tagion}

#
# Hashgraph view
#
# fixme(cbr): When ddeps.mk work those libs are not needed
target-graphview: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
${call DO_BIN,graphview,$(LIB_DFILES) ${call BIN_DEPS,graphview},tagion}

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

target-tagion: DFLAGS+=$(DVERSION)=ONETOOL
target-tagion: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
${call DO_BIN,tagion,$(LIB_DFILES) $(TAGION_BINS)}


#
# Binary of BBD generator tool
#
target-collider: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
<<<<<<< HEAD
${call DO_BIN,collider,$(LIB_DFILES) ${call BIN_DEPS,collider}}

target-libtagion: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
target-libtagion: DLIBTYPE?=$(DSTATICLIB)
target-libtagion: DFLAGS+=$(DLIBTYPE)
target-libtagion: DFILES:=${shell find $(DSRC) -name "*.d" -a -path "*/src/lib-*" -a -not -path "*/unitdata/*" -a -not -path "*/tests/*" -a -not -path "*/lib-betterc/*" $(NO_WOLFSSL) }
${call DO_BIN,libtagion,}

=======
target-collider: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-collider/*" -a -not -path "*/unitdata/*" $(NO_WOLFSSL) }
${call DO_BIN,collider,}
>>>>>>> 1926f80be93e599151110cbc1aa54622b2e21596
