include git.mk
-include $(REPOROOT)/localsetup.mk
PACKAGE:=hibon
include $(MAINROOT)/submodule_default_setup.mk

LIBS+=${call GETLIB,tagion_basic}
LIBS+=${call GETLIB,tagion_utils}
#LIBS+=${call GETLIB,tagion_hibon}
#LIBS+=${call GETLIB,tagion_hashgraph}
#LIBS+=${call GETLIB,tagion_crypto}
#LIBS+=${call GETLIB,tagion_services}
#LIBS+=$(LIBSECP256K1)
