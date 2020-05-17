REPOROOT?=${shell git root}
-include $(REPOROOT)/localsetup.mk

ifndef NOUNITTEST
DCFLAGS+=-unittest
DCFLAGS+=-g
DCFLAGS+=$(DEBUG)
endif

DCFLAGS+=$(DIP1000) # Should support scope c= new C; // is(C == class)
DCFLAGS+=$(DIP25)

SCRIPTROOT:=${REPOROOT}/scripts/

WAVMROOT:=${REPOROOT}/../WAVM/
# WAVM C-header file
WAVM_H:=${WAVMROOT}/Include/WAVM/wavm-c/wavm-c.h
WAVM_DI_ROOT:=../../../wavm/
WAVM_DI:=wavm/c/wavm.di
WAVM_PACKAGE:=wavm.c
# Change c-array to pointer
WAVMa2p:=${SCRIPTROOT}/wasm_array2pointer.pl

WAYS+=$(WAVM_DI_ROOT)

LIBNAME:=libwasm.a

# DDOC Configuration
#
-include ddoc.mk

BIN:=$(REPOROOT)/bin/
BUILD?=$(REPOROOT)/build

WAYS+=${BIN}
WAYS+=${BUILD}

SOURCE:=tagion

-include dstep.mk

TAGION_CORE:=$(REPOROOT)/../tagion_core/

INC+=$(REPOROOT)/tagion
INC+=$(TAGION_CORE)
INC+=$(P2PLIB)
INC+=$(SECP256K1ROOT)/src/
INC+=$(SECP256K1ROOT)/
