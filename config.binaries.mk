
#
# Targets for all binaries
#

#
# Core program
#
target-tagionwave: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-wave/*" -a -not -path "*/unitdata/*" }
${call BIN,tagionwave,TAGIONWAVE,$(LIBOPENSSL) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)}

#
# HiBON utility
#
# FIXME(CBR) should be remove when ddeps works correctly
target-hibonutil: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-hibonutil/*" -a -not -path "*/unitdata/*" }
${call BIN,hibonutil,HIBONUTIL,$(LIBOPENSSL) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)}


#
# DART utility
#
# FIXME(CBR) should be remove when ddeps works correctly
target-dartutil: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-dartutil/*" -a -not -path "*/unitdata/*" }
${call BIN,dartutil,DARTUTIL,$(LIBOPENSSL) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)}

#
# WASM utility
#
# FIXME(CBR) should be remove when ddeps works correctly
target-wasmutil: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-wasmutil/*" -a -not -path "*/unitdata/*" }
${call BIN,wasmutil,WASMUTIL,$(LIBOPENSSL) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)}

#
# WASM utility
#
# FIXME(CBR) should be remove when ddeps works correctly
target-wallet: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-wallet/*" -a -not -path "*/unitdata/*" }
${call BIN,wallet,TAGIONWALLET,$(LIBOPENSSL) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)}

#
# Logservicetest utility
#
# FIXME(IB) should be removed when ddeps works correctly
target-tagionlogservicetest: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-logservicetest/*" -a -not -path "*/unitdata/*" }
${call BIN,tagionlogservicetest,LOGSERVICETEST,$(LIBOPENSSL) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)}

#
# Subscription utility
#
# FIXME(IB) should be removed when ddeps works correctly
target-tagionsubscription: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-subscription/*" -a -not -path "*/unitdata/*" }
${call BIN,tagionsubscription,SUBSCRIPTION,$(LIBOPENSSL) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)}

#
# Recorderchain utility
#
target-recorderchain: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-recorderchain/*" -a -not -path "*/unitdata/*" }
${call BIN,recorderchain,RECORDERCHAIN,$(LIBOPENSSL) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)}

#
# Boot utility
#
# fixme(cbr): When ddeps.mk work those libs are not needed
target-tagionboot: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-boot/*" -a -not -path "*/unitdata/*" }
${call BIN,tagionboot,TAGIONBOOT,$(LIBOPENSSL) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)}
