include git.mk
-include $(REPOROOT)/localsetup.mk
PACKAGE:=monitor
include $(MAINROOT)/submodule_default_setup.mk

LIBS+=${call GETLIB,tagion_basic}
LIBS+=${call GETLIB,tagion_utils}
LIBS+=${call GETLIB,tagion_hibon}
LIBS+=${call GETLIB,tagion_hashgraph}
IBS+=${call GETLIB,tagion_gossip}
IBS+=${call GETLIB,tagion_network}
#LIBS+=${call GETLIB,tagion_crypto}
#LIBS+=${call GETLIB,tagion_dart}

LIBS+=$(LIBSECP256K1)
LIBS+=$(LIBP2P)
LIBS+=$(LIBP2P_GO)

LDCFLAGS+=$(LDCFLAGS_GMP)
LDCFLAGS+=$(LDCFLAGS_CRYPT)
