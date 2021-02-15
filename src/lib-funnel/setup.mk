include git.mk
-include $(REPOROOT)/localsetup.mk
SOURCE:=tagion/script
PACKAGE:=funnel
PACKAGE_MODULE:=tagion.script
REVISION:=tagion/script/revision.di

include $(MAINROOT)/submodule_default_setup.mk

LIBS+=${call GETLIB,tagion_basic}
LIBS+=${call GETLIB,tagion_utils}
LIBS+=${call GETLIB,tagion_hibon}
#LIBS+=${call GETLIB,tagion_gossip}
#LIBS+=${call GETLIB,tagion_hashgraph}
LIBS+=${call GETLIB,tagion_crypto}
#LIBS+=${call GETLIB,tagion_dart}
#LIBS+=${call GETLIB,tagion_wallet}
#LIBS+=${call GETLIB,tagion_communication}
#LIBS+=${call GETLIB,tagion_services}
LIBS+=$(LIBSECP256K1)
LIBS+=$(LIBP2P)
LIBS+=$(LIBP2P_GO)

LDCFLAGS+=$(LDCFLAGS_GMP)
LDCFLAGS+=$(LDCFLAGS_CRYPT)
LDCFLAGS+=$(LDCFLAGS_SSL)
