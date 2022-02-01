include git.mk
-include $(REPOROOT)/localsetup.mk
PACKAGE:=dart
include $(MAINROOT)/submodule_default_setup.mk

LIBS+=${call GETLIB,tagion_basic}
LIBS+=${call GETLIB,tagion_utils}
