include git.mk
#REPOROOT?=${shell git rev-parse --show-toplevel}
DC:=$(REPOROOT)/../tagion_main/tagion_betterc/ldc2-1.20.1-linux-x86_64/bin/ldc2
LD:=$(REPOROOT)/../tagion_main/tools/wasi-sdk/bin/wasm-ld

WAMR_DIR:=$(REPOROOT)/../wasm-micro-runtime/
SRC:=.
BIN:=bin

LDWFLAGS+=-O0
MAIN?=hibon
include dfiles.mk
# ifeq ($(MAIN),test_array)
DFILES+=tests/$(MAIN).d

# SYMBOLS+=char_array
# SYMBOLS+=ref_char_array
# SYMBOLS+=const_char_array
# SYMBOLS+=get_result
# endif

# ifeq ($(MAIN),test_struct)
# DFILES:=$(MAIN).d

# #SYMBOLS+=set_s
# #SYMBOLS+=ref_char_array
# #SYMBOLS+=const_char_array
# #SYMBOLS+=get_result
# endif

#LDWFLAGS+=--allow-undefined-file=${REPOROOT}/share/defined-symbols.txt
LDWFLAGS+=--allow-undefined


# do-all:
# 	$(MAKE) MAIN=test_array all
# 	$(MAKE) MAIN=test_struct all
