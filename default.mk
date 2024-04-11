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
DFLAGS+=$(DVERSION)=REDBLACKTREE_SAFE_PROBLEM

# This fixes an error in the app wallet where it would be logged out after each operation
# By copying the securenet each time an operation is done
# DFLAGS+=$(DVERSION)=NET_HACK

# Sets the inputvalidators NNG socket to be blocking
DFLAGS+=$(DVERSION)=BLOCKING

# Fix a randomly occurring RangeError on hashgraph startup
# By filtering out empty events
DFLAGS+=$(DVERSION)=EPOCH_FIX

# This allows an experimental nft function to be used without payment
# The function is not used in this node
DFLAGS+=$(DVERSION)=WITHOUT_PAYMENT

# Use compile time sorted, serialization of dart branches
#DFLAGS+=$(DVERSION)=DARTFile_BRANCHES_SERIALIZER

# Dart optimization that inserts segments sorted.
# Before it would sort the segments every time they were needed
DFLAGS+=$(DVERSION)=WITHOUT_SORTING

# Always use the Genesis epoch to determine the boot nodes
# There is currently no way to function to determine the nodes from latest epoch
DFLAGS+=$(DVERSION)=USE_GENESIS_EPOCH

# Flags for enabling different order_less functions for the hashgraph
# See refinement
# NEW_ORDERING uses PseudoTime
# OLD_ORDERING uses old simple method
# DFLAGS+=$(DVERSION)=NEW_ORDERING 
DFLAGS+=$(DVERSION)=OLD_ORDERING

# Flag for random delay between messages
# see GossipNet
# DFLAGS+=$(DVERSION)=RANDOM_DELAY

# HashGraph.d not_used_channels turn on check of
# node.state is ExchangeState.NONE. Mode1 does not function with this.
# DFLAGS+=$(DVERSOIN)=SEND_ALWAYS

# Enable verbose epoch logging
# DFLAGS+=$(DVERSION)=EPOCH_LOG

# Enable websocket pub in shell. 
# Currently causes the program not to stop properly in bddtests.
# DFLAGS+=$(DVERSION)=TAGIONSHELL_WEB_SOCKET

# # This enables a redundant check in dart to see if there are overlaps between segments 
# DFLAGS+=$(DVERSION)=DART_RECYCLER_INVARIANT

# # This is used for the wallet wrapper to generate pseudo random history
# # which is useful for app development
# DFLAGS+=$(DVERSION)=WALLET_HISTORY_DUMMY

# # This fixes the names of some reserved archives which were not reserved
# # $@Vote && @Locked
# # This is a breaking change so it's not enabled by default
# DFLAGS+=$(DVERSION)=RESERVED_ARCHIVES_FIX

# Use to check that toHiBON.serialize is equal to .serialize
#DFLAGS+=$(DVERSION)=TOHIBON_SERIALIZE_CHECK

# This is used to intentionaly provoke a crash in the app.
# Needed for GDB testing.
# DFLAGS+=$(DVERSION)=PROVOKE_CRASH

# Use to write logs into a file.
DFLAGS+=$(DDEBUG)=android

# Extra DFLAGS for the testbench 
BDDDFLAGS+=$(DDEBUG_SYMBOLS)
BDDDFLAGS+=$(DEXPORT_DYN)

INSTALL?=$(HOME)/bin

#ENABLE_WASMER?=1
