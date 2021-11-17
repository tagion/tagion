# OS & ATCH
OS ?= $(shell uname | tr A-Z a-z)

ifndef ARCH
ifeq ($(OS),"windows")
ifeq ($(PROCESSOR_ARCHITECTURE), x86)
ARCH = x86
else
ARCH = x86_64
endif
else
ARCH = $(shell uname -m)
endif
endif

# PRECMD is used to add command before the compiliation commands
PRECMD ?= @

# Git
GIT_ORIGIN := "git@github.com:tagion"

# 
# Commands
# 

# Define commands for copy, remove and create file/dir
ifeq ($(OS),windows)
RM := del /Q
RMDIR := del /Q
CP := copy /Y
MKDIR := mkdir
MV := move
LN := mklink
else ifeq ($(OS),linux)
RM := rm -f
RMDIR := rm -rf
CP := cp -fr
MKDIR := mkdir -p
MV := mv
LN := ln -s
else ifeq ($(OS),freebsd)
RM := rm -f
RMDIR := rm -rf
CP := cp -fr
MKDIR := mkdir -p
MV := mv
LN := ln -s
else ifeq ($(OS),solaris)
RM := rm -f
RMDIR := rm -rf
CP := cp -fr
MKDIR := mkdir -p
MV := mv
LN := ln -s
else ifeq ($(OS),darwin)
RM := rm -f
RMDIR := rm -rf
CP := cp -fr
MKDIR := mkdir -p
MV := mv
LN := ln -s
endif

# 
# Cross compilation
# 
# machine-vendor-operatingsystem
TRIPLET ?= $(ARCH)-unknown-$(OS)

TRIPLET_SPACED := ${subst -, ,$(TRIPLET)}

# If TRIPLET specified with 2 words
# fill the VENDOR as unknown
CROSS_ARCH := ${word 1, $(TRIPLET_SPACED)}
ifeq (${words $(TRIPLET_SPACED)},2)
CROSS_VENDOR := unknown
CROSS_OS := ${word 2, $(TRIPLET_SPACED)}
else
CROSS_VENDOR := ${word 2, $(TRIPLET_SPACED)}
CROSS_OS := ${word 3, $(TRIPLET_SPACED)}
endif

CROSS_COMPILE := 1

# If same as host - reset vars not to trigger
# cross-compilation logic
ifeq ($(CROSS_ARCH),$(ARCH))
ifeq ($(CROSS_OS),$(OS))
CROSS_ARCH :=
CROSS_VENDOR :=
CROSS_OS :=
CROSS_COMPILE :=
endif
endif

MTRIPLE := $(CROSS_ARCH)-$(CROSS_VENDOR)-$(CROSS_OS)
ifeq ($(MTRIPLE),--)
MTRIPLE := $(TRIPLET)
endif

MAKE_SHOW_ENV += env-cross
env-cross:
	$(call log.header, env :: cross)
	$(call log.kvp, MTRIPLE, $(MTRIPLE))
	$(call log.kvp, CROSS_COMPILE, $(CROSS_COMPILE))
	$(call log.kvp, CROSS_ARCH, $(CROSS_ARCH))
	$(call log.kvp, CROSS_VENDOR, $(CROSS_VENDOR))
	$(call log.kvp, CROSS_OS, $(CROSS_OS))
	$(call log.close)

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

# Define D Improvement Proposals
ifeq ($(COMPILER),ldc)
DCFLAGS += $(DIP25)
DCFLAGS += $(DIP1000)
endif

# Define relocation model for ldc or other
ifeq ($(COMPILER),ldc)
# FPIC = -relocation-model=pic
else
# FPIC = -fPIC
endif

# Add -ldl flag for linux
ifeq ($(OS),"linux")
LDCFLAGS += $(LINKERFLAG)-ldl
endif

# Define model if not defined
ifndef MODEL
ifeq ($(ARCH), $(filter $(ARCH), x86_64 arm64))
MODEL = 64
else
MODEL = 32
endif
endif

# -m32 and -m64 switches cannot be used together with -march and -mtriple switches
ifndef CROSS_OS
ifeq ($(MODEL), 64)
DCFLAGS  += -m64
LDCFLAGS += -m64
else
DCFLAGS  += -m32
LDCFLAGS += -m32
endif
endif

MAKE_SHOW_ENV += env-compiler
env-compiler:
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
# Directories
# 
DIR_TRASH := ${abspath ${DIR_ROOT}}/.trash
DIR_BUILD := ${abspath ${DIR_ROOT}}/build/$(MTRIPLE)
DIR_BUILD_TEMP := ${abspath ${DIR_BUILD}}/.tmp
DIR_BUILD_FLAGS := ${abspath ${DIR_BUILD}}/.tmp/flags
DIR_BUILD_O := $(DIR_BUILD_TEMP)/o
DIR_BUILD_LIBS_STATIC := $(DIR_BUILD)/libs/static
DIR_BUILD_BINS := $(DIR_BUILD)/bins
DIR_BUILD_WRAPS := $(DIR_BUILD)/wraps
DIR_SRC := ${abspath ${DIR_ROOT}}/src

# New simplified flow directories
DBIN := $(DIR_BUILD)/bin
DTMP := $(DIR_BUILD)/tmp

MAKE_SHOW_ENV += env-dirs
env-dirs:
	$(call log.header, env :: dirs)
	$(call log.kvp, DIR_TRASH, $(DIR_TRASH))
	$(call log.kvp, DIR_ROOT, $(DIR_ROOT))
	$(call log.kvp, DIR_TUB, $(DIR_TUB))
	$(call log.separator)
	$(call log.kvp, DIR_BUILD, $(DIR_BUILD))
	$(call log.kvp, DIR_SRC, $(DIR_SRC))
	$(call log.close)

#
# Modes
#
# TODO: Inherit parallel value from current make
MAKE_PARALLEL := -j
MAKE_DEBUG := 

MAKE_SHOW_ENV += env-mode
env-mode:
	$(call log.header, env :: tub mode)
	$(call log.kvp, MAKE_PARALLEL, $(MAKE_PARALLEL))
	$(call log.kvp, MAKE_DEBUG, $(MAKE_DEBUG))
	$(call log.close)

MAKE_SHOW_ENV += env-commands
env-commands:
	$(call log.header, env :: commands ($(OS)))
	$(call log.kvp, RM, $(RM))
	$(call log.kvp, RMDIR, $(RMDIR))
	$(call log.kvp, MKDIR, $(MKDIR))
	$(call log.kvp, MV, $(MV))
	$(call log.kvp, LN, $(LN))
	$(call log.close)

env: $(MAKE_SHOW_ENV)

# 
# Utility variables
# 
FCONFIGURE := gen.configure.mk