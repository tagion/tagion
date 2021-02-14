include git.mk
-include $(REPOROOT)/localsetup.mk
PACKAGE:=communication
include $(MAINROOT)/submodule_default_setup.mk

LIBS+=${call GETLIB,tagion_basic}
LIBS+=${call GETLIB,tagion_utils}
LIBS+=${call GETLIB,tagion_hibon}
#LIBS+=${call GETLIB,tagion_hashgraph}
#IBS+=${call GETLIB,tagion_gossip}
LIBS+=${call GETLIB,tagion_crypto}
#LIBS+=${call GETLIB,tagion_dart}

LIBS+=$(LIBSECP256K1)
LIBS+=$(LIBP2P)
LIBS+=$(LIBP2P_GO)

LDCFLAGS+=$(LDCFLAGS_GMP)
LDCFLAGS+=$(LDCFLAGS_CRYPT)
