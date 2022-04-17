
#
# Targets for all binaries
#

#
# Core program
#
target-tagionwave: LIBS+=$(LIBOPENSSL)
target-tagionwave: LIBS+=$(LIBSECP256K1)
target-tagionwave: LIBS+=$(LIBP2PGOWRAPPER)
target-tagionwave: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-wave/*" -a -not -path "*/unitdata/*" }
target-tagionwave: $(DBIN)/tagionwave
.PHONY: target-tagionwave

clean-tagionwave:
	$(PRECMD)
	${call log.header, $@ :: clean}
	$(RM) $(DBIN)/tagionwave

clean: clean-tagionwave

#
# HiBON utility
#
# FIXME(CBR) should be remove when ddeps works correctly
target-hibonutil: LIBS+=$(LIBOPENSSL)
target-hibonutil: LIBS+=$(LIBSECP256K1)
target-hibonutil: LIBS+=$(LIBP2PGOWRAPPER)

target-hibonutil: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-hibonutil/*" -a -not -path "*/unitdata/*"}
target-hibonutil: $(DBIN)/hibonutil

clean-hibonutil:
	$(PRECMD)
	${call log.header, $@ :: clean}
	$(RM) $(DBIN)/hibonutil

clean: clean-hibonutil

#
# DART utility
#
# FIXME(CBR) should be remove when ddeps works correctly
target-dartutil: LIBS+=$(LIBOPENSSL)
target-dartutil: LIBS+=$(LIBSECP256K1)
target-dartutil: LIBS+=$(LIBP2PGOWRAPPER)
target-dartutil: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-dartutil/*" -a -not -path "*/unitdata/*"}
target-dartutil: $(DBIN)/dartutil

clean-dartutil:
	$(PRECMD)
	${call log.header, $@ :: clean}
	$(RM) $(DBIN)/dartutil

clean: clean-dartutil

BIN_TARGETS+=target-dartutil

#
# WASM utility
#
# FIXME(CBR) should be remove when ddeps works correctly
target-wasmutil: LIBS+=$(LIBOPENSSL)
target-wasmutil: LIBS+=$(LIBSECP256K1)
target-wasmutil: LIBS+=$(LIBP2PGOWRAPPER)
target-wasmutil: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-wasmutil/*" -a -not -path "*/unitdata/*"}
target-wasmutil: $(DBIN)/wasmutil

clean-wasmutil:
	$(PRECMD)
	${call log.header, $@ :: clean}
	$(RM) $(DBIN)/wasmutil

clean: clean-wasmutil


#
# WASM utility
#
# FIXME(CBR) should be remove when ddeps works correctly
target-wallet: LIBS+=$(LIBOPENSSL)
target-wallet: LIBS+=$(LIBSECP256K1)
target-wallet: LIBS+=$(LIBP2PGOWRAPPER)
target-wallet: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-wallet/*" -a -not -path "*/unitdata/*"}
target-wallet: $(DBIN)/wallet

clean-wallet:
	$(PRECMD)
	${call log.header, $@ :: clean}
	$(RM) $(DBIN)/wallet

clean: clean-wallet




#
# Logservicetest utility
#
# FIXME(IB) should be removed when ddeps works correctly
target-tagionlogservicetest: LIBS+=$(LIBOPENSSL)
target-tagionlogservicetest: LIBS+=$(LIBSECP256K1)
target-tagionlogservicetest: LIBS+=$(LIBP2PGOWRAPPER)

target-tagionlogservicetest: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-logservicetest/*"}
target-tagionlogservicetest: $(DBIN)/tagionlogservicetest

clean-tagionlogservicetest:
	$(PRECMD)
	${call log.header, $@ :: clean}
	$(RM) $(DBIN)/tagionlogservicetest

clean: clean-tagionlogservicetest

BIN_TARGETS+=target-tagionlogservicetest


#
# Subscription utility
#
# FIXME(IB) should be removed when ddeps works correctly
target-tagionsubscription: LIBS+=$(LIBOPENSSL)
target-tagionsubscription: LIBS+=$(LIBSECP256K1)
target-tagionsubscription: LIBS+=$(LIBP2PGOWRAPPER)

target-tagionsubscription: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-subscription/*"}
target-tagionsubscription: $(DBIN)/tagionsubscription

clean-tagionsubscription:
	$(PRECMD)
	${call log.header, $@ :: clean}
	$(RM) $(DBIN)/tagionsubscription

clean: clean-tagionsubscription

BIN_TARGETS+=target-tagionsubscription


#
# Recorderchain utility
#
# FIXME(IB) should be removed when ddeps works correctly
target-recorderchain: LIBS+=$(LIBOPENSSL)
target-recorderchain: LIBS+=$(LIBSECP256K1)
target-recorderchain: LIBS+=$(LIBP2PGOWRAPPER)

target-recorderchain: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-recorderchain/*"}
target-recorderchain: $(DBIN)/recorderchain

clean-recorderchain:
	$(PRECMD)
	${call log.header, $@ :: clean}
	$(RM) $(DBIN)/recorderchain

clean: clean-recorderchain

hibonutil: target-hibonutil
bin: hibonutil

dartutil: target-dartutil
bin: dartutil

wasmutil: target-wasmutil
bin: wasmutil

wallet: target-wallet
bin: wallet

tagionwave: target-tagionwave
bin: tagionwave

tagionlogservicetest: target-tagionlogservicetest
bin: tagionlogservicetest

tagionsubscription: target-tagionsubscription
bin: tagionsubscription

recorderchain: target-recorderchain
bin: recorderchain


