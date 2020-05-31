include git.mk
#REPOROOT?=${shell git rev-parse --show-toplevel}
TOOLS_DIR?=$(REPOROOT)/../tools/
DC:=$(TOOLS_DIR)/ldc/bin/ldc2
LD:=$(TOOLS_DIR)/wasi-sdk/bin/wasm-ld

WAMR_DIR:=$(REPOROOT)/../wasm-micro-runtime/
SRC:=.
BIN:=bin

LDWFLAGS+=-O0
MAIN?=hibon
include dfiles.mk
# ifeq ($(MAIN),test_array)
DFILES+=tests/$(MAIN).d

#LDWFLAGS+=--allow-undefined-file=${REPOROOT}/share/defined-symbols.txt
LDWFLAGS+=--allow-undefined
