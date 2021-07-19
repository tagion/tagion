include git.mk
-include $(REPOROOT)/localsetup.mk
PACKAGE:=wasm
PACKAGE_MODULE?=tagion.vm.$(PACKAGE)
include $(MAINROOT)/submodule_default_setup.mk
SOURCE:=tagion/vm
REVISION:=$(SOURCE)/$(PACKAGE)/revision.di

LIBS+=${call GETLIB,tagion_basic}
LIBS+=${call GETLIB,tagion_utils}
#LIBS+=${call GETLIB,tagion_hibon}
#LIBS+=${call GETLIB,tagion_hashgraph}
#LIBS+=${call GETLIB,tagion_crypto}
#LIBS+=${call GETLIB,tagion_services}
#LIBS+=$(LIBSECP256K1)
