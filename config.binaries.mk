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
EXCLUDED_DIRS+=-a -not -path "*/lib-zmqd/zmqd/examples/*"
ifndef STLZMQ
EXCLUDED_DIRS+=-a -not -path "*/lib-zmqd/*"
EXCLUDED_DIRS+=-a -not -path "*/lib-demos/*"
else
ZMQIMPLEMENTATION=$(LIBSTLZMQ)
LIBS+=$(LIBZMQ)
endif

LIB_DFILES:=${shell find $(DSRC) -name "*.d" -a -path "*/lib-*" $(EXCLUDED_DIRS) $(NO_UNITDATA) }

env-dfiles:
	$(PRECMD)
	$(call log.header, $@ :: env)
	$(call log.env, LIB_DFILES, $(LIB_DFILES))
	$(call log.close)

.PHONY: env-dfiles

env: env-dfiles

env-exclude-dirs:
	$(PRECMD)
	$(call log.header, $@ :: env)
	$(call log.env, EXCLUDED_DIRS, $(EXCLUDED_DIRS))
	$(call log.close)

.PHONY: env-exclude-dirs

env: env-exclude-dirs
 
LIB_BETTERC:=${shell find $(DSRC) -name "*.d" -a -path "*/lib-betterc/*" -a -not -path "*/tests/*" $(NO_UNITDATA) }


BIN_DEPS=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-$1/*" $(EXCLUDED_DIRS) $(NO_UNITDATA) $(NO_WOLFSSL) }


#
# Targets for all binaries
#

#
# Core program
#
target-tagionwave: LIBS+= $(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
${call DO_BIN,tagionwave,$(LIB_DFILES) ${call BIN_DEPS,priorwave},tagion}

#
# New Wave
#
target-neuewelle: LIBS+= $(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
${call DO_BIN,neuewelle,$(LIB_DFILES) ${call BIN_DEPS,wave},tagion}


#
# HiBON utility
#
target-hibonutil: LIBS+= $(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
${call DO_BIN,hibonutil,$(LIB_DFILES) ${call BIN_DEPS,hibonutil},tagion}


#
# DART utility
#
target-dartutil: LIBS+= $(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
${call DO_BIN,dartutil,$(LIB_DFILES) ${call BIN_DEPS,dartutil},tagion}

#
# DART utility
#
target-blockutil: LIBS+= $(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
${call DO_BIN,blockutil,$(LIB_DFILES) ${call BIN_DEPS,blockutil},tagion}

#
# WASM utility
#
target-wasmutil: LIBS+= $(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
${call DO_BIN,wasmutil,$(LIB_DFILES) ${call BIN_DEPS,wasmutil},tagion}

#
# WASM utility
#
target-tagionwallet: LIBS+= $(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
${call DO_BIN,tagionwallet,$(LIB_DFILES) ${call BIN_DEPS,tagionwallet},tagion}

wallet: target-tagionwallet


target-signs: LIBS+= $(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
${call DO_BIN,signs,$(LIB_DFILES) ${call BIN_DEPS,signs},tagion}

#
# Subscription utility
#
#target-tagionsubscription: LIBS+= $(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
#${call DO_BIN,subscription,$(LIB_DFILES) ${call BIN_DEPS,subsciption}}

#
# Recorderchain utility
#
#target-recorderchain: LIBS+= $(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
#${call DO_BIN,recorderchain,$(LIB_DFILES) ${call BIN_DEPS,recorderchain},tagion}

#
# Boot utility
#
# fixme(cbr): When ddeps.mk work those libs are not needed
target-tagionboot: LIBS+= $(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
${call DO_BIN,tagionboot,$(LIB_DFILES) ${call BIN_DEPS,boot},tagion}

#
# Profile view
#
# fixme(cbr): When ddeps.mk work those libs are not needed
target-tprofview: LIBS+= $(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
${call DO_BIN,tprofview,$(LIB_DFILES) ${call BIN_DEPS,tprofview},tagion}

#
# Hashgraph view
#
# fixme(cbr): When ddeps.mk work those libs are not needed
target-graphview: LIBS+= $(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
${call DO_BIN,graphview,$(LIB_DFILES) ${call BIN_DEPS,graphview},tagion}

#
# Tagion onetool
#
TAGION_TOOLS+=priorwave
TAGION_TOOLS+=wave # New wave
TAGION_TOOLS+=dartutil
TAGION_TOOLS+=blockutil
TAGION_TOOLS+=hibonutil
TAGION_TOOLS+=wallet
TAGION_TOOLS+=tprofview
TAGION_TOOLS+=boot
TAGION_TOOLS+=tools
TAGION_TOOLS+=graphview
TAGION_TOOLS+=recorderchain
TAGION_TOOLS+=signs
TAGION_TOOLS+=wasmutil

TAGION_BINS=$(foreach tools,$(TAGION_TOOLS), ${call BIN_DEPS,$(tools)} )

target-tagion: DFLAGS+=$(DVERSION)=ONETOOL
target-tagion: LIBS+= $(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
${call DO_BIN,tagion,$(LIB_DFILES) $(TAGION_BINS)}


#
# Binary of BBD generator tool
#
target-collider: DFLAGS+=$(DVERSION)=ONETOOL
target-collider: LIBS+= $(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
${call DO_BIN,collider,$(LIB_DFILES) ${call BIN_DEPS,collider}}

