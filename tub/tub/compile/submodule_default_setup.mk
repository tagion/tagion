include $(DIR_SCRIPTS)/setup.mk

TESTDCFLAGS+=-I$(REPOROOT)/tests/
TESTDCFLAGS+=-unittest
TESTDCFLAGS+=-g
TESTDCFLAGS+=$(DEBUG)

DCFLAGS+=$(DIP1000) # Should support scope c= new C; // is(C == class)
DCFLAGS+=$(DIP25)
DCFLAGS+=$(DVERSION)=NO_MEMBER_LIST
DCFLAGS+=-g
DCFLAGS+=$(DEBUG)

LDCFLAGS+=$(LINKERFLAG)-export-dynamic

ifdef LOGGER
DCFLAGS+=$(DVERSION)=LOGGER # Enables task name to be added for TagionExceptions
endif



WAYS+=${BINDIR}
WAYS+=${LIBDIR}
GETLIB=$(LIBDIR)/lib$(1).a

LIBNAME?=tagion_$(PACKAGE)
LIBRARY?=${call GETLIB,$(LIBNAME)}
#$(LIBDIR)/$(LIBNAME)

SOURCE?=tagion/$(PACKAGE)
#SOURCE?=tagion
#PACKAGE:=${subst /,.,$(SOURCE)}
REVISION?=$(REPOROOT)/$(SOURCE)/revision.di

INC+=$(REPOROOT)

include unittest_setup.mk

LIBSGMP:=/usr/local/homebrew/Cellar/gmp/6.2.1/lib/libgmp.a
LIBSOPENSSL:=$(DIR_LAB)/openssl/libssl.a
LIBSCRYPTO:=$(DIR_LAB)/openssl/libcrypto.a
LIBSECP256K1:=$(DIR_LAB)/secp256k1/.libs/libsecp256k1.a
LIBP2P:=$(DIR_LAB)/libp2pDWrapper/bin//libp2p.a
LIBP2P_GO:=$(DIR_LAB)/libp2pDWrapper/bin//libp2p_go.a

LDCFLAGS_GMP:=$(LINKERFLAG)-lgmp
LDCFLAGS_SSL:=$(LINKERFLAG)-lssl
LDCFLAGS_CRYPT:=$(LINKERFLAG)-lcrypto
