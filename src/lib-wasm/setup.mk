include git.mk
-include $(REPOROOT)/localsetup.mk
PACKAGE:=wasm
PACKAGE_MODULE?=tagion.vm.$(PACKAGE)
include $(MAINROOT)/submodule_default_setup.mk
SOURCE:=tagion/vm
REVISION:=$(SOURCE)/$(PACKAGE)/revision.di
