include git.mk
-include $(REPOROOT)/localsetup.mk

TESTDCFLAGS+=-I$(REPOROOT)/tests/
TESTDCFLAGS+=-unittest
TESTDCFLAGS+=-g
TESTDCFLAGS+=$(DEBUG)

DCFLAGS+=$(DIP1000) # Should support scope c= new C; // is(C == class)
DCFLAGS+=$(DIP25)
DCFLAGS+=$(DVERSION)=NO_MEMBER_LIST

SCRIPTROOT:=${REPOROOT}/scripts/



# DDOC Configuration
#
-include ddoc.mk

BIN:=bin

LIBNAME:=libtagion_hibon.a
LIBRARY:=$(BIN)/$(LIBNAME)

WAYS+=${BIN}
WAYS+=tests

SOURCE:=tagion/hibon
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
