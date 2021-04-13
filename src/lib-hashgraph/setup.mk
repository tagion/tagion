include git.mk
-include $(REPOROOT)/localsetup.mk
PACKAGE:=hashgraph
include $(MAINROOT)/submodule_default_setup.mk

LIBS+=${call GETLIB,tagion_basic}
LIBS+=${call GETLIB,tagion_utils}
LIBS+=${call GETLIB,tagion_hibon}
LIBS+=${call GETLIB,tagion_gossip}
LIBS+=${call GETLIB,tagion_crypto}
# Dependence of DART should maybe be removed
LIBS+=${call GETLIB,tagion_dart}
LIBS+=${call GETLIB,tagion_communication}

LIBS+=$(LIBSECP256K1)
LIBS+=$(LIBP2P)
LIBS+=$(LIBP2P_GO)

LDCFLAGS+=$(LDCFLAGS_GMP)
LDCFLAGS+=$(LDCFLAGS_CRYPT)
LDCFLAGS+=$(LDCFLAGS_SSL)
DCFLAGS+=$(DVERSION)=hashgraph_fibertest
