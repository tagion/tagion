include git.mk
-include $(REPOROOT)/localsetup.mk
PACKAGE:=utils
include $(MAINROOT)/submodule_default_setup.mk

LIBS+=${call GETLIB,tagion_basic}
