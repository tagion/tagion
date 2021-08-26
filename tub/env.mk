# OS
OS ?= $(shell uname)

# PRECMD is used to add command before the compiliation commands
PRECMD ?= @

# Git
GIT_ORIGIN := "git@github.com:tagion"

# 
# Compiler
# 

# If compiler is not defined, try to find it
ifndef DC
ifneq ($(strip $(shell which ldc2 2>/dev/null)),)
DC=ldc2
else ifneq ($(strip $(shell which ldc 2>/dev/null)),)
DC=ldc
else ifneq ($(strip $(shell which dmd 2>/dev/null)),)
DC=dmd
else
DC=gdc
endif
endif

# Define a compiler family for other conditionals
ifeq ($(DC),gdc)
COMPILER=gdc
else ifeq ($(DC),gdmd)
COMPILER=gdc
else ifeq ($(DC),ldc)
COMPILER=ldc
else ifeq ($(DC),ldc2)
COMPILER=ldc
else ifeq ($(DC),ldmd)
COMPILER=ldc
else ifeq ($(DC),dmd)
COMPILER=dmd
else ifeq ($(DC),dmd2)
COMPILER=dmd
endif

# Define flags for gdc other
ifeq ($(COMPILER),gdc)
DCFLAGS	= -O2
LINKERFLAG= -Xlinker
OUTPUT	= -o
HF		= -fintfc-file=
DF		= -fdoc-file=
NO_OBJ	= -fsyntax-only
DDOC_MACRO= -fdoc-inc=
else
DCFLAGS	= -O
LINKERFLAG= -L
OUTPUT	= -of
HF		= -Hf
DF		= -Df
DD		= -Dd
NO_OBJ	= -o-
DDOC_MACRO=
endif

# Define version statement / soname flag
ifeq ($(COMPILER),ldc)
DVERSION = -d-version
SONAME_FLAG = -soname
DEBUG ?= -d-debug
DIP := --dip
else ifeq ($(COMPILER),gdc)
DVERSION = -fversion
SONAME_FLAG = $(LINKERFLAG)-soname
DEBUG ?= -f-d-debug
DIP := unknown-dip
else
DVERSION = -version
SONAME_FLAG = $(LINKERFLAG)-soname
DEBUG ?= -debug
DIP := -dip
endif

DIP25 := $(DIP)25
DIP1000 := $(DIP)1000

# Define relocation model for ldc or other
ifeq ($(COMPILER),ldc)
# FPIC = -relocation-model=pic
else
# FPIC = -fPIC
endif

# Add -ldl flag for linux
ifeq ($(OS),"Linux")
LDCFLAGS += $(LINKERFLAG)-ldl
endif

# Define architecture, if not defined explicitly
ifndef ARCH
ifeq ($(OS),"Windows")
ifeq ($(PROCESSOR_ARCHITECTURE), x86)
ARCH = x86
else
ARCH = x86_64
endif
else
ARCH = $(shell uname -m)
endif
endif

# Define model if not defined
ifndef MODEL
ifeq ($(ARCH), $(filter $(ARCH), x86_64 arm64))
MODEL = 64
else
MODEL = 32
endif
endif

ifeq ($(MODEL), 64)
DCFLAGS  += -m64
LDCFLAGS += -m64
else
DCFLAGS  += -m32
LDCFLAGS += -m32
endif

MAKE_SHOW_ENV += env/compiler
env/compiler:
	$(call log.header, env :: compiler)
	$(call log.kvp, DC, $(DC))
	$(call log.kvp, COMPILER, $(COMPILER))
	$(call log.kvp, ARCH, $(ARCH))
	$(call log.kvp, MODEL, $(MODEL))
	$(call log.separator)
	$(call log.kvp, DCFLAGS (Complier), $(DCFLAGS))
	$(call log.kvp, LDCFLAGS (Linker), $(LDCFLAGS))
	$(call log.kvp, SOURCEFLAGS, $(SOURCEFLAGS))
	$(call log.separator)
	$(call log.kvp, OUTPUT, $(OUTPUT))
	$(call log.kvp, HF, $(HF))
	$(call log.kvp, DF, $(DF))
	$(call log.kvp, NO_OBJ, $(NO_OBJ))
	$(call log.separator)
	$(call log.kvp, SONAME_FLAG, $(SONAME_FLAG))
	$(call log.kvp, DVERSION, $(DVERSION))
	$(call log.kvp, DEBUG, $(DEBUG))
	$(call log.separator)
	$(call log.kvp, DIP, $(DIP))
	$(call log.kvp, DIP25, $(DIP25))
	$(call log.kvp, DIP1000, $(DIP1000))
	$(call log.separator)
	$(call log.kvp, FPIC, $(FPIC))
	$(call log.close)

# 
# Commands
# 

# Define commands for copy, remove and create file/dir
ifeq ($(OS),Windows)
RM := del /Q
RMDIR := del /Q
CP := copy /Y
MKDIR := mkdir
MV := move
LN := mklink
else ifeq ($(OS),Linux)
RM := rm -f
RMDIR := rm -rf
CP := cp -fr
MKDIR := mkdir -p
MV := mv
LN := ln -s
else ifeq ($(OS),FreeBSD)
RM := rm -f
RMDIR := rm -rf
CP := cp -fr
MKDIR := mkdir -p
MV := mv
LN := ln -s
else ifeq ($(OS),Solaris)
RM := rm -f
RMDIR := rm -rf
CP := cp -fr
MKDIR := mkdir -p
MV := mv
LN := ln -s
else ifeq ($(OS),Darwin)
RM := rm -f
RMDIR := rm -rf
CP := cp -fr
MKDIR := mkdir -p
MV := mv
LN := ln -s
endif

# 
# Directories
# 
DIR_TUB_ROOT := ${realpath ${DIR_TUB}/../}
DIR_BUILD := ${realpath ${DIR_TUB_ROOT}}/build/$(ARCH)
DIR_SRC := ${realpath ${DIR_TUB_ROOT}}/src

MAKE_SHOW_ENV += env/dirs
env/dirs:
	$(call log.header, env :: dirs)
	$(call log.kvp, DIR_TUB_ROOT, $(DIR_TUB_ROOT))
	$(call log.kvp, DIR_TUB, $(DIR_TUB))
	$(call log.separator)
	$(call log.kvp, DIR_BUILD, $(DIR_BUILD))
	$(call log.kvp, DIR_SRC, $(DIR_SRC))
	$(call log.close)

MAKE_SHOW_ENV += env/commands
env/commands:
	$(call log.header, env :: commands ($(OS)))
	$(call log.kvp, RM, $(RM))
	$(call log.kvp, RMDIR, $(RMDIR))
	$(call log.kvp, MKDIR, $(MKDIR))
	$(call log.kvp, MV, $(MV))
	$(call log.kvp, LN, $(LN))
	$(call log.close)

env: $(MAKE_SHOW_ENV)