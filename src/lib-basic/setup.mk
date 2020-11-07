include git.mk
-include $(REPOROOT)/localsetup.mk

ifndef NOUNITTEST
DCFLAGS+=-I$(REPOROOT)/tests/
DCFLAGS+=-unittest
DCFLAGS+=-g
DCFLAGS+=$(DEBUG)
endif

DCFLAGS+=$(DIP1000) # Should support scope c= new C; // is(C == class)
DCFLAGS+=$(DIP25)
DCFLAGS+=$(DVERSION)=NO_MEMBER_LIST

ifdef LOGGER
DCFLAGS+=$(DVERSION)=LOGGER # Enables task name to be added for TagionExceptions
endif

SCRIPTROOT:=${REPOROOT}/scripts/



# DDOC Configuration
#
-include ddoc.mk

BIN:=bin

LIBNAME:=libtagion_basic.a
LIBRARY:=$(BIN)/$(LIBNAME)

WAYS+=${BIN}

SOURCE:=tagion/basic
PACKAGE:=${subst /,.,$(SOURCE)}
REVISION:=$(REPOROOT)/$(SOURCE)/revision.di

-include dstep.mk


INC+=$(REPOROOT)

include unittest_setup.mk
