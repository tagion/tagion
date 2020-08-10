include git.mk
-include $(REPOROOT)/localsetup.mk

TESTDCFLAGS+=-I$(REPOROOT)/tests/
TESTDCFLAGS+=-unittest
TESTDCFLAGS+=-g
TESTDCFLAGS+=$(DEBUG)

DCFLAGS+=$(DIP1000) # Should support scope c= new C; // is(C == class)
DCFLAGS+=$(DIP25)
DCFLAGS+=$(DEBUG)
DCFLAGS+=-g
DCFLAGS+=$(DEBUG)

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

LIBNAME:=libtagion_wasm.a

# DDOC Configuration
#
-include ddoc.mk

BIN:=$(REPOROOT)/bin/

WAYS+=${BIN}
WAYS+=tests

SOURCE:=tagion/vm/wasm
PACKAGE:=${subst /,.,$(SOURCE)}
REVISION:=$(REPOROOT)/$(SOURCE)/revision.d

-include dstep.mk

TAGION_BASIC:=$(REPOROOT)/../tagion_basic/
TAGION_UTILS:=$(REPOROOT)/../tagion_utils/
#TAGION_CORE:=$(REPOROOT)/../tagion_core/

-include core_dfiles.mk
include tagion_dfiles.mk

INC+=$(TAGION_BASIC)
INC+=$(TAGION_UTILS)
#INC+=$(TAGION_CORE)
INC+=$(REPOROOT)

include unittest_setup.mk
