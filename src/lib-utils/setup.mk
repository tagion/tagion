include git.mk
-include $(REPOROOT)/localsetup.mk

LIBNAME:=libtagion_utils.a
ifndef NOUNITTEST
DCFLAGS+=-I$(REPOROOT)/tests/
DCFLAGS+=-unittest
DCFLAGS+=-g
DCFLAGS+=$(DEBUG)
endif

DCFLAGS+=$(DIP1000) # Should support scope c= new C; // is(C == class)
DCFLAGS+=$(DIP25)
DCFLAGS+=$(DVERSION)=NO_MEMBER_LIST

SCRIPTROOT:=${REPOROOT}/scripts/


# WAMR_ROOT:=$(REPOROOT)/../wasm-micro-runtime/
# LIBS+=$(WAMR_ROOT)/wamr-compiler/build/libvmlib.a

# DDOC Configuration
#
-include ddoc.mk

BIN:=bin

LIBNAME:=libtagion_utils.a
LIBRARY:=$(BIN)/$(LIBNAME)

WAYS+=${BIN}
WAYS+=tests

SOURCE:=tagion/utils
PACKAGE:=${subst /,.,$(SOURCE)}
REVISION:=$(REPOROOT)/$(SOURCE)/revision.di

-include dstep.mk

TAGION_BASIC:=$(REPOROOT)/../tagion_basic/
TAGION_CORE:=$(REPOROOT)/../tagion_core/

include tagion_dfiles.mk

INC+=$(TAGION_BASIC)
INC+=$(TAGION_CORE)
INC+=$(REPOROOT)

include unittest_setup.mk
