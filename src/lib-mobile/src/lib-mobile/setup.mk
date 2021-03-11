include git.mk
-include $(REPOROOT)/localsetup.mk
PACKAGE:=wallet
include $(MAINROOT)/submodule_default_setup.mk

LIBS+=${call GETLIB,tagion_basic}
LIBS+=${call GETLIB,tagion_utils}
LIBS+=${call GETLIB,tagion_hibon}
#LIBS+=${call GETLIB,tagion_gossip}
LIBS+=${call GETLIB,tagion_crypto}
LIBS+=${call GETLIB,tagion_funnel}
#LIBS+=${call GETLIB,tagion_services}
#LIBS+=${call GETLIB,tagion_hashgraph}
#LIBS+=${call GETLIB,tagion_communication}
#LIBS+=${call GETLIB,tagion_dart}

LIBS+=$(LIBSECP256K1)
#LIBS+=$(LIBP2P)
#LIBS+=$(LIBP2P_GO)

LDCFLAGS+=$(LDCFLAGS_GMP)
LDCFLAGS+=$(LDCFLAGS_CRYPT)
