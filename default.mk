#DC?=dmd
DEBUGGER?=ddd
VERBOSE_COMPILER_ERRORS=1
# SECP256K1_DEBUG=1

export TEST_STAGE:=commit
export SEED:=$(shell git rev-parse HEAD)

RELEASE_DFLAGS+=$(DOPT)

# USE_SYSTEM_LIBS=1 # Compile with system libraries (nng & secp256k1-zkp)

# If you are using system libraries nng is most likely be compiled with mbedtls support
# So mbedtls needs to be linked as well, so this need to be enabled
# NNG_ENABLE_TLS=1

ifndef DEBUG_DISABLE
DFLAGS+=$(DDEBUG_SYMBOLS)
endif

DFLAGS+=$(DWARN)

# Uses a modified version of phobos' redblacktree
# So it's more compatiblae with @safe code
DVERSIONS+=REDBLACKTREE_SAFE_PROBLEM

# This fixes an error in the app wallet where it would be logged out after each operation
# By copying the securenet each time an operation is done
DVERSIONS+=NET_HACK

# Sets the inputvalidators NNG socket to be blocking
DVERSIONS+=BLOCKING

# Fix a randomly occurring RangeError on hashgraph startup
# By filtering out empty events
DVERSIONS+=EPOCH_FIX

# This allows an experimental nft function to be used without payment
# The function is not used in this node
DVERSIONS+=WITHOUT_PAYMENT

# Use compile time sorted, serialization of dart branches
#DVERSIONS+=DARTFile_BRANCHES_SERIALIZER

# Dart optimization that inserts segments sorted.
# Before it would sort the segments every time they were needed
DVERSIONS+=WITHOUT_SORTING

# Always use the Genesis epoch to determine the boot nodes
# There is currently no way to function to determine the nodes from latest epoch
DVERSIONS+=USE_GENESIS_EPOCH

# Flags for enabling different order_less functions for the hashgraph
# See refinement
# NEW_ORDERING uses PseudoTime
# OLD_ORDERING uses old simple method
# DVERSIONS+=NEW_ORDERING 
DVERSIONS+=OLD_ORDERING

# Flag for random delay between messages
# see GossipNet
# DVERSIONS+=RANDOM_DELAY

# HashGraph.d not_used_channels turn on check of
# node.state is ExchangeState.NONE. Mode1 does not function with this.
# DVERSIONS=SEND_ALWAYS

# Enable verbose epoch logging
# DVERSIONS+=EPOCH_LOG

# Enable websocket pub in shell. 
# Currently causes the program not to stop properly in bddtests.
# DVERSIONS+=TAGIONSHELL_WEB_SOCKET

# # This enables a redundant check in dart to see if there are overlaps between segments 
# DVERSIONS+=DART_RECYCLER_INVARIANT

# # This fixes the names of some reserved archives which were not reserved
# # $@Vote && @Locked
# # This is a breaking change so it's not enabled by default
# DVERSIONS+=RESERVED_ARCHIVES_FIX

# Use to check that toHiBON.serialize is equal to .serialize
#DVERSIONS+=TOHIBON_SERIALIZE_CHECK

# Runs a stopwatch on all unittest modules
# DVERSIONS+=UNIT_STOPWATCH

# Extra DFLAGS for the testbench 
BDDDFLAGS+=$(DDEBUG_SYMBOLS)
BDDDFLAGS+=$(DEXPORT_DYN)

INSTALL?=$(HOME)/bin

#ENABLE_WASMER?=1
