#DC?=dmd
DEBUGGER?=ddd
VERBOSE_COMPILER_ERRORS=1
# SECP256K1_DEBUG=1

export TEST_STAGE:=commit
export SEED:=$(shell git rev-parse HEAD)

RELEASE_DFLAGS+=$(DOPT)

# Enable all debug flags
DEBUG_ENABLE?=1

# Debug symbols added
# SYMBOLS_ENABLE=1

# ERROR || INFO || undef
# enable informational 
WARNINGS?=INFO

# USE_SYSTEM_LIBS=1 # Compile with system libraries (nng & secp256k1-zkp)

# If you are using system libraries nng is most likely be compiled with mbedtls support
# So mbedtls needs to be linked as well, so this need to be enabled
# NNG_ENABLE_TLS=1

# Uses a modified version of phobos' redblacktree
# So it's more compatiblae with @safe code
DVERSIONS+=REDBLACKTREE_SAFE_PROBLEM

# This fixes an error in the app wallet where it would be logged out after each operation
# By copying the securenet each time an operation is done
DVERSIONS+=NET_HACK

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
#DVERSIONS+=OLD_ORDERING
DVERSIONS+=HASH_ORDERING

# Flag for enabling printing in C-API
# DVERIONS+=C_API_DEBUG

# Flag for random delay between messages
# see GossipNet
# DVERSIONS+=RANDOM_DELAY

# Enable verbose epoch logging
# DVERSIONS+=EPOCH_LOG

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
# This can also be enable via the environment UNIT_STOPWATCH
# export UNIT_STOPWARCH 1
# The unittest can also be selected by a list of modules
# Ex. 
# export UNIT_MODULE tagion.hibon.Document
# Or
# make unittest UNIT_MODULE+=tagion.hibon.Document UNIT_MODULE+=tagion.hibon.HiBON
# Or just add the local.mk


INSTALL?=$(HOME)/.local/bin

#ENABLE_WASMER?=1
#UNSHARE_NET=1


# God Contract only for test purpose
# Enables to send dart-modify directly to the network
# DVERSION+=GOD_CONTRACT

# DVERSIONS+=USE_DART_SYNC
# DVERSIONS+=DEDICATED_DART_SYNC_FIBER

