include git.mk
#REPOROOT?=${shell git rev-parse --show-toplevel}
TOOLS_DIR?=$(REPOROOT)/../tools/
DC:=ldc2
LD:=/opt/wasi-sdk/bin/wasm-ld

WAMR_DIR:=$(REPOROOT)/../wasm-micro-runtime/
SRC:=.
BIN:=bin

LDWFLAGS+=-O0
MAIN?=hibon
<<<<<<< HEAD
-include dfiles.mk
=======
include dfiles.mk
>>>>>>> 4f386fd9a5d04e3a5776a225aa91fba2a399caaa
# ifeq ($(MAIN),test_array)
DFILES+=tests/$(MAIN).d

#LDWFLAGS+=--allow-undefined-file=${REPOROOT}/share/defined-symbols.txt
LDWFLAGS+=--allow-undefined
