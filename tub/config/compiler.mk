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

# D step
# TODO: Clone local dstep
DSTEP:=dstep

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

INCLFLAGS := ${addprefix -I,${shell ls -d $(DSRC)/*/ 2> /dev/null || true | grep -v wrap-}}

MAKE_ENV += env-compiler
env-compiler:
	$(PRECMD)
	$(call log.header, env :: compiler)
	$(call log.kvp, DC, $(DC))
	$(call log.kvp, COMPILER, $(COMPILER))
	$(call log.kvp, ARCH, $(ARCH))
	$(call log.kvp, MODEL, $(MODEL))
	$(call log.kvp, OUTPUT, $(OUTPUT))
	$(call log.kvp, HF, $(HF))
	$(call log.kvp, DF, $(DF))
	$(call log.kvp, NO_OBJ, $(NO_OBJ))
	$(call log.kvp, SONAME_FLAG, $(SONAME_FLAG))
	$(call log.kvp, DVERSION, $(DVERSION))
	$(call log.kvp, DEBUG, $(DEBUG))
	$(call log.kvp, DIP, $(DIP))
	$(call log.kvp, DIP25, $(DIP25))
	$(call log.kvp, DIP1000, $(DIP1000))
	$(call log.kvp, FPIC, $(FPIC))
	$(call log.kvp, DCFLAGS (Complier), $(DCFLAGS))
	$(call log.kvp, LDCFLAGS (Linker), $(LDCFLAGS))
	$(call log.kvp, SOURCEFLAGS, $(SOURCEFLAGS))
	$(call log.close)
