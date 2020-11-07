include git.mk
-include $(REPOROOT)/localsetup.mk
PACKAGE:=basic
include $(MAINROOT)/submodule_default_setup.mk

# LIBNAME:=libtagion_basic.a
# LIBRARY:=$(BIN)/$(LIBNAME)

# SOURCE:=tagion/basic
# PACKAGE:=${subst /,.,$(SOURCE)}
# REVISION:=$(REPOROOT)/$(SOURCE)/revision.di

# INC+=$(REPOROOT)

# include unittest_setup.mk
