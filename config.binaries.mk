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
EXCLUDED_DIRS+=-a -not -path "*/.dub/*"

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
# New Wave
#
target-neuewelle: LIBS+= $(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER) $(LIBNNG)
${call DO_BIN,neuewelle,$(LIB_DFILES) ${call BIN_DEPS,wave},tagion}

#
# Shell
#
target-tagionshell: LIBS+= $(LIBNNG)
${call DO_BIN,tagionshell,$(LIB_DFILES) ${call BIN_DEPS,tagionshell},tagion}

#
# New Wallet
#
target-geldbeutel: LIBS+= $(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER) 
${call DO_BIN,geldbeutel,$(LIB_DFILES) ${call BIN_DEPS,geldbeutel},tagion}

#
# New tagion boot
#
target-stiefel: LIBS+= $(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER) 
${call DO_BIN,stiefel,$(LIB_DFILES) ${call BIN_DEPS,stiefel},tagion}

#
#  HiBON reqular expression print
#
target-hirep: LIBS+= $(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER) 
${call DO_BIN,hirep,$(LIB_DFILES) ${call BIN_DEPS,hirep},tagion}



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


target-signs: LIBS+= $(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
${call DO_BIN,signs,$(LIB_DFILES) ${call BIN_DEPS,signs},tagion}

#
# Recorderchain utility
#
target-recorderchain: LIBS+= $(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
${call DO_BIN,recorderchain,$(LIB_DFILES) ${call BIN_DEPS,recorderchain},tagion}


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
TAGION_TOOLS+=wave # New wave
TAGION_TOOLS+=dartutil
TAGION_TOOLS+=blockutil
TAGION_TOOLS+=hibonutil
TAGION_TOOLS+=wallet
TAGION_TOOLS+=tprofview
TAGION_TOOLS+=tools
TAGION_TOOLS+=graphview
TAGION_TOOLS+=signs
TAGION_TOOLS+=recorderchain
TAGION_TOOLS+=wasmutil
TAGION_TOOLS+=geldbeutel
TAGION_TOOLS+=tagionshell
TAGION_TOOLS+=stiefel
TAGION_TOOLS+=hirep

TAGION_BINS=$(foreach tools,$(TAGION_TOOLS), ${call BIN_DEPS,$(tools)} )

target-tagion: ssl nng secp256k1 libp2p
target-tagion: DFLAGS+=$(DVERSION)=ONETOOL
target-tagion: LIBS+= $(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER) $(LIBNNG)
${call DO_BIN,tagion,$(LIB_DFILES) $(TAGION_BINS)}

env-tools:
	$(PRECMD)
	$(call log.header, $@ :: env)
	$(call log.env, TAGION_TOOLS, $(TAGION_TOOLS))
	$(call log.env, TAGION_BINS, $(TAGION_BINS))
	$(call log.close)

#
# Binary of BBD generator tool
#
target-collider: DFLAGS+=$(DVERSION)=ONETOOL
target-collider: LIBS+= $(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER) $(LIBNNG)
${call DO_BIN,collider,$(LIB_DFILES) ${call BIN_DEPS,collider}}

