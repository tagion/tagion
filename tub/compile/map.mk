UNIT_LIST_LIB :=
UNIT_LIST_BIN :=
UNIT_LIST_WRAP :=

# Libs 
UNIT_LIST_LIB += lib-basic
UNIT_LIST_LIB += lib-utils
UNIT_LIST_LIB += lib-hibon
UNIT_LIST_LIB += lib-p2pgowrapper
UNIT_LIST_LIB += lib-crypto
UNIT_LIST_LIB += lib-dart
UNIT_LIST_LIB += lib-funnel
UNIT_LIST_LIB += lib-gossip
UNIT_LIST_LIB += lib-hashgraph
UNIT_LIST_LIB += lib-network
UNIT_LIST_LIB += lib-services
UNIT_LIST_LIB += lib-wallet
UNIT_LIST_LIB += lib-wasm
UNIT_LIST_LIB += lib-communication
UNIT_LIST_LIB += lib-monitor
UNIT_LIST_LIB += lib-logger
UNIT_LIST_LIB += lib-options
UNIT_LIST_LIB += lib-client

# Bins
UNIT_LIST_BIN += bin-wave
UNIT_LIST_BIN += bin-hibonutil
UNIT_LIST_BIN += bin-dartutil
UNIT_LIST_BIN += bin-clientutil
UNIT_LIST_BIN += bin-wasmutil

#  Wraps
UNIT_LIST_WRAP += wrap-secp256k1
UNIT_LIST_WRAP += wrap-openssl
UNIT_LIST_WRAP += wrap-p2pgowrapper

# All
UNIT_LIST := $(UNIT_LIST_LIB) $(UNIT_LIST_BIN) $(UNIT_LIST_WRAP)

map:
	${call log.header, available units}
	${call log.kvp, Libs}
	${call log.lines, $(UNIT_LIST_LIB)}
	${call log.kvp, Bins}
	${call log.lines, $(UNIT_LIST_BIN)}
	${call log.kvp, Wraps}
	${call log.lines, $(UNIT_LIST_WRAP)}
	${call log.close}