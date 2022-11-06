export GODEBUG=cgocheck=0

ifdef WOLFSSL
SSLIMPLEMENTATION=$(LIBWOLFSSL)
else
SSLIMPLEMENTATION=$(LIBOPENSSL)
NO_WOLFSSL=-a -not -path "*/wolfssl/*"
endif


#
# Targets for all binaries
#

#
# Core program
#
#tagion-tagionwave: DFLANG+=$(DONETOOL)
target-tagionwave: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
target-tagionwave: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-wave/*" -a -not -path "*/unitdata/*" $(NO_WOLFSSL) }
${call DO_BIN,tagionwave,tagion}

#
# HiBON utility
#
# FIXME(CBR) should be remove when ddeps works correctly
target-hibonutil: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
target-hibonutil: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-hibonutil/*" -a -not -path "*/unitdata/*" $(NO_WOLFSSL) }
${call DO_BIN,hibonutil,tagion}


#
# DART utility
#
# FIXME(CBR) should be remove when ddeps works correctly
target-dartutil: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
target-dartutil: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-dartutil/*" -a -not -path "*/unitdata/*" $(NO_WOLFSSL) }
${call DO_BIN,dartutil,tagion}

#
# WASM utility
#
# FIXME(CBR) should be remove when ddeps works correctly
target-wasmutil: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
target-wasmutil: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-wasmutil/*" -a -not -path "*/unitdata/*" $(NO_WOLFSSL) }
${call DO_BIN,wasmutil,}

#
# WASM utility
#
# FIXME(CBR) should be remove when ddeps works correctly
target-tagionwallet: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
target-tagionwallet: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-wallet/*" -a -not -path "*/unitdata/*" $(NO_WOLFSSL) }
${call DO_BIN,tagionwallet,tagion}

wallet: target-tagionwallet
#
# Logservicetest utility
#
# FIXME(IB) should be removed when ddeps works correctly
target-tagionlogservicetest: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
target-tagionlogservicetest: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-logservicetest/*" -a -not -path "*/unitdata/*" $(NO_WOLFSSL) }
${call DO_BIN,tagionlogservicetest,}

#
# Subscription utility
#
# FIXME(IB) should be removed when ddeps works correctly
target-tagionsubscription: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
target-tagionsubscription: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-subscription/*" -a -not -path "*/unitdata/*" $(NO_WOLFSSL) }
${call DO_BIN,tagionsubscription,}

#
# Recorderchain utility
#
target-recorderchain: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
target-recorderchain: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-recorderchain/*" -a -not -path "*/unitdata/*" $(NO_WOLFSSL) }
${call DO_BIN,recorderchain,}

#
# Boot utility
#
# fixme(cbr): When ddeps.mk work those libs are not needed
target-tagionboot: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
target-tagionboot: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-boot/*" -a -not -path "*/unitdata/*" -a -not -path "*/lib-betterc/*" $(NO_WOLFSSL) }
${call DO_BIN,tagionboot,tagion}

target-tagion: DFLAGS+=$(DVERSION)=ONETOOL
target-tagion: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
target-tagion: DFILES:=${shell find $(DSRC) -name "*.d" -a -path "*/src/lib-*" -a -not -path "*/unitdata/*" -a -not -path "*/tests/*" -a -not -path "*/lib-betterc/*" $(NO_WOLFSSL) }
target-tagion: DFILES+=${shell find $(DSRC)/bin-wave/tagion -name "*.d"  $(NO_WOLFSSL) }
target-tagion: DFILES+=${shell find $(DSRC)/bin-dartutil/tagion -name "*.d"  $(NO_WOLFSSL) }
target-tagion: DFILES+=${shell find $(DSRC)/bin-hibonutil/tagion -name "*.d"  $(NO_WOLFSSL) }
target-tagion: DFILES+=${shell find $(DSRC)/bin-wallet/tagion -name "*.d"  $(NO_WOLFSSL) }
target-tagion: DFILES+=${shell find $(DSRC)/bin-tools/tagion -name "*.d"  $(NO_WOLFSSL) }
target-tagion: DFILES+=${shell find $(DSRC)/bin-boot/tagion -name "*.d"  $(NO_WOLFSSL) }

target-tagion:
${call DO_BIN,tagion,}

#
# Binary of BBD generator tool
#
target-behaviour: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
target-behaviour: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-behaviour/*" -a -not -path "*/unitdata/*" $(NO_WOLFSSL) }
${call DO_BIN,behaviour,}

#
# Binary testbench 
#
target-testbench: DFLAGS+=$(DVERSION)=ONETOOL
target-testbench: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
target-testbench: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-testbench/*" -a -not -path "*/unitdata/*" $(NO_WOLFSSL) }
${call DO_BIN,testbench,}
