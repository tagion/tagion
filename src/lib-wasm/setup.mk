include git.mk
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

SOURCE:=tagion/vm
PACKAGE:=${subst /,.,$(SOURCE)}
REVISION:=$(REPOROOT)/$(SOURCE)/revision.di

-include dstep.mk

TAGION_BASIC:=$(REPOROOT)/../tagion_basic/
TAGION_UTILS:=$(REPOROOT)/../tagion_utils/
TAGION_CORE:=$(REPOROOT)/../tagion_core/

-include core_dfiles.mk
include tagion_dfiles.mk

INC+=$(TAGION_BASIC)
INC+=$(TAGION_UTILS)
#INC+=$(TAGION_CORE)
INC+=$(REPOROOT)

include unittest_setup.mk
