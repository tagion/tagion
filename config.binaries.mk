SRC_DFILES=$(shell find $(DSRC) -name "*.d")
BIN_DINC=$(shell find $(DSRC) -maxdepth 1 -type d -path "*/src/bin-*" )
SRC_DINC=$(shell find $(DSRC) -maxdepth 1 -type d -path "*/src/bin-*" -or -path "*/src/lib-*")

env-dinc:
	$(PRECMD)
	$(call log.header, $@ :: env)
	$(call log.env, SRC_DINC, $(SRC_DINC))
	$(call log.env, BIN_DINC, $(BIN_DINC))
	$(call log.close)

.PHONY: env-dinc
env: env-dinc

env-dfiles:
	$(PRECMD)
	$(call log.header, $@ :: env)
	$(call log.env, SRC_DFILES, $(SRC_DFILES))
	$(call log.close)

.PHONY: env-dfiles

env: env-dfiles

env-tools:
	$(PRECMD)
	$(call log.header, $@ :: env)
	$(call log.env, TAGION_TOOLS, $(TAGION_TOOLS))
	$(call log.close)

.PHONY: env-tools

env: env-tools

# $1: target name
define DO_BIN
${eval
$(DBIN)/$1: | revision
$(DBIN)/$1: $(SRC_DFILES)
$1: $(DBIN)/$1
.PHONY: $1
TAGION_TOOLS+=$1
}
endef

#
# New tagion wave
#
$(DBIN)/neuewelle: secp256k1 nng
$(DBIN)/neuewelle: LDFLAGS+=$(LD_SECP256K1) $(LD_NNG)
$(DBIN)/neuewelle: DINC+=$(SRC_DINC)
$(DBIN)/neuewelle: DFILES::=$(DSRC)/bin-wave/tagion/tools/neuewelle.d
$(call DO_BIN,neuewelle)

#
# Shell
#
$(DBIN)/tagionshell: secp256k1 nng
$(DBIN)/tagionshell: LDFLAGS+=$(LD_SECP256K1) $(LD_NNG)
$(DBIN)/tagionshell: DINC+=$(SRC_DINC)
$(DBIN)/tagionshell: DFILES::=$(DSRC)/bin-tagionshell/tagion/tools/tagionshell.d
$(call DO_BIN,tagionshell)

#
# Tagion Wallet
#
$(DBIN)/geldbeutel: secp256k1 nng
$(DBIN)/geldbeutel: LDFLAGS+=$(LD_SECP256K1) $(LD_NNG)
$(DBIN)/geldbeutel: DINC+=$(SRC_DINC)
$(DBIN)/geldbeutel: DFILES::=$(DSRC)/bin-geldbeutel/tagion/tools/wallet/geldbeutel.d
$(call DO_BIN,geldbeutel)

#
# Tagion payout 
#
$(DBIN)/auszahlung: secp256k1 nng
$(DBIN)/auszahlung: LDFLAGS+=$(LD_SECP256K1) $(LD_NNG)
$(DBIN)/auszahlung: DINC+=$(SRC_DINC)
$(DBIN)/auszahlung: DFILES::=$(DSRC)/bin-auszahlung/tagion/tools/auszahlung/auszahlung.d
$(call DO_BIN,auszahlung)

#
# Tagion boot
#
$(DBIN)/stiefel: secp256k1
$(DBIN)/stiefel: LDFLAGS+=$(LD_SECP256K1)
$(DBIN)/stiefel: DINC+=$(SRC_DINC)
$(DBIN)/stiefel: DFILES::=$(DSRC)/bin-stiefel/tagion/tools/boot/stiefel.d
$(call DO_BIN,stiefel)

#
#  HiBON reqular expression print
#
$(DBIN)/hirep: secp256k1
$(DBIN)/hirep: LDFLAGS+=$(LD_SECP256K1)
$(DBIN)/hirep: DINC+=$(SRC_DINC)
$(DBIN)/hirep: DFILES::=$(DSRC)/bin-hirep/tagion/tools/hirep/hirep.d
$(call DO_BIN,hirep)

#
# HiBON utility
#
$(DBIN)/hibonutil: secp256k1
$(DBIN)/hibonutil: LDFLAGS+=$(LD_SECP256K1)
$(DBIN)/hibonutil: DINC+=$(SRC_DINC)
$(DBIN)/hibonutil: DFILES::=$(DSRC)/bin-hibonutil/tagion/tools/hibonutil.d
$(call DO_BIN,hibonutil)

#
# DART utility
#
$(DBIN)/dartutil: secp256k1
$(DBIN)/dartutil: LDFLAGS+=$(LD_SECP256K1)
$(DBIN)/dartutil: DINC+=$(SRC_DINC)
$(DBIN)/dartutil: DFILES::=$(DSRC)/bin-dartutil/tagion/tools/dartutil/dartutil.d
$(call DO_BIN,dartutil)

#
# Blocfile utility
#
$(DBIN)/blockutil: DINC+=$(SRC_DINC)
$(DBIN)/blockutil: DFILES::=$(DSRC)/bin-blockutil/tagion/tools/blockutil.d
$(call DO_BIN,blockutil)

#
# WASM utility
#
$(DBIN)/wasmutil: DINC+=$(SRC_DINC)
$(DBIN)/wasmutil: DFILES::=$(DSRC)/bin-wasmutil/tagion/tools/wasmutil/wasmutil.d
$(call DO_BIN,wasmutil)

#
# Signature util
#
$(DBIN)/signs: secp256k1
$(DBIN)/signs: LDFLAGS+=$(LD_SECP256K1)
$(DBIN)/signs: DINC+=$(SRC_DINC)
$(DBIN)/signs: DFILES::=$(DSRC)/bin-signs/tagion/tools/signs.d
$(call DO_BIN,signs)

#
# kette recorderchain utility
#
$(DBIN)/kette: secp256k1
$(DBIN)/kette: LDFLAGS+=$(LD_SECP256K1)
$(DBIN)/kette: DINC+=$(SRC_DINC)
$(DBIN)/kette: DFILES::=$(DSRC)/bin-recorderchain/tagion/tools/kette.d
$(call DO_BIN,kette)

#
# Converting an old data-base to a new one
#
$(DBIN)/vergangenheit: secp256k1 nng
$(DBIN)/vergangenheit: LDFLAGS+=$(LD_SECP256K1) $(LD_NNG)
$(DBIN)/vergangenheit: DINC+=$(SRC_DINC)
$(DBIN)/vergangenheit: DFILES::=$(DSRC)/bin-vergangenheit/tagion/tools/vergangenheit/vergangenheit.d
$(call DO_BIN,vergangenheit)

#
# Tagion virtual machine utility
#
$(DBIN)/tvmutil: libwasmer
$(DBIN)/tvmutil: LDFLAGS+=$(LIBWASMER) 
$(DBIN)/tvmutil: DINC+=$(SRC_DINC)
$(DBIN)/tvmutil: DFILES::=$(DSRC)/bin-tvmutil/tagion/tools/tvmutil/tvmutil.d
$(call DO_BIN,tvmutil)

#
# Profile view
#
$(DBIN)/tprofview: DINC+=$(SRC_DINC)
$(DBIN)/tprofview: DFILES::=$(DSRC)/bin-tprofview/tagion/tools/tprofview.d
$(call DO_BIN,tprofview)

#
# Hashgraph view
#
$(DBIN)/graphview: secp256k1 nng
$(DBIN)/graphview: LDFLAGS+=$(LD_SECP256K1) $(LD_NNG)
$(DBIN)/graphview: DINC+=$(SRC_DINC)
$(DBIN)/graphview: DFILES::=$(DSRC)/bin-graphview/tagion/tools/graphview.d
$(call DO_BIN,graphview)

#
#  callstack
#
$(DBIN)/callstack: DINC+=$(SRC_DINC)
$(DBIN)/callstack: DFILES::=$(DSRC)/bin-callstack/tagion/tools/callstack/callstack.d
$(call DO_BIN,callstack)

#
#  file watching util
#
$(DBIN)/ifiler: DINC+=$(SRC_DINC)
$(DBIN)/ifiler: DFILES::=$(DSRC)/bin-ifiler/tagion/tools/ifiler/ifiler.d
$(call DO_BIN,ifiler)

#
# Subscriber
#
$(DBIN)/subscriber: nng secp256k1
$(DBIN)/subscriber: LDFLAGS+=$(LD_NNG) $(LD_SECP256K1)
$(DBIN)/subscriber: DINC+=$(SRC_DINC)
$(DBIN)/subscriber: DFILES::=$(DSRC)/bin-subscriber/tagion/tools/subscriber.d
$(call DO_BIN,subscriber)

#
# ONETOOL
#
ifdef ENABLE_WASMER
$(DBIN)/tagion: libwasmer
endif
$(DBIN)/tagion: nng secp256k1 
$(DBIN)/tagion: LDFLAGS+=$(LD_SECP256K1) $(LD_NNG) $(LIBWASMER)
$(DBIN)/tagion: DFILES::=$(DSRC)/bin-tools/tagion/tools/tools.d
$(DBIN)/tagion: DINC+=$(SRC_DINC)
$(DBIN)/tagion: DFLAGS+=$(DVERSION)=ONETOOL
$(call DO_BIN,tagion)

#
# Binary of BBD generator tool
#
COLLIDER::=$(DBIN)/collider
$(COLLIDER): DFILES::=$(DSRC)/bin-collider/tagion/tools/collider/collider.d
$(COLLIDER): DINC+=$(SRC_DINC)
$(COLLIDER): DFLAGS+=$(DVERSION)=ONETOOL
$(call DO_BIN,collider)

all-tools: $(TAGION_TOOLS)
.PHONY: all-tools
