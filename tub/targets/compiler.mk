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
COMPILER=dmd
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
DOPT	= -O2
LINKERFLAG= -Xlinker
OUTPUT	= -o
HF		= -fintfc-file=
DF		= -fdoc-file=
NO_OBJ	= -fsyntax-only
DDOC_MACRO= -fdoc-inc=
else
DOPT	= -O
LINKERFLAG= -L
OUTPUT	= -of
HF		= -Hf
DF		= -Df
DD		= -Dd
DDOC_MACRO=
endif

# Define version statement / soname flag
ifeq ($(COMPILER),ldc)
DVERSION := -d-version
SONAME_FLAG := -soname
DDEBUG := -d-debug
DMAIN := -f-d-main
DUNITTEST := --unittest
DMAIN := --main
DIP := --dip
DFPIC := -relocation-model=pic
DDEBUG_SYMBOLS := -g
DBETTERC := --betterC
DCOMPILE_ONLY := -c
DPREVIEW :=--preview
NO_OBJ ?= --o-
DJSON ?= --Xf
DEXPORT_DYN?=-L-export-dynamic
DCOV=--cov
DIMPORTFILE=-J
DDEFAULTLIBSTATIC=-link-defaultlib-shared=false
DSTATICLIB=--lib
DSHAREDLIB=--shared
OUTPUTDIR = --od
else ifeq ($(COMPILER),gdc)
DVERSION := -fversion
SONAME_FLAG := $(LINKERFLAG)-soname
DDEBUG := -fdebug
DUNITTEST := -funittest
DMAIN := -fmain
DIP := -ftransition=dip
DDEBUG_SYMBOLS := -g
DBETTERC := --betterC
DCOMPILE_ONLY := -c
DPREVIEW :=-preview
NO_OBJ ?= -o-
DCOV ?=-cov
DSTATICLIB=-lib
DSHAREDLIB=-shared
OUTPUTDIR = -od
else
DVERSION = -version
SONAME_FLAG = $(LINKERFLAG)-soname
DDEBUG := -debug
DUNITTEST := -unittest
DMAIN := -main
DIP := -dip
DFPIC := -fPIC
DDEBUG_SYMBOLS := -g
DBETTERC := -betterC
DCOMPILE_ONLY := -c
DPREVIEW :=-preview
NO_OBJ ?= -o-
DJSON ?= -Xf
DCOV ?=-cov
DIMPORTFILE=-J
DINCIMPORT= -i
DSTATICLIB=-lib
DSHAREDLIB=-shared
OUTPUTDIR = -od
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
DFLAGS  += -m64
LDCFLAGS += -m64
else
DFLAGS  += -m32
LDCFLAGS += -m32
endif
endif

INCLFLAGS := ${addprefix -I,${shell ls -d $(DSRC)/*/ 2> /dev/null || true | grep -v wrap-}}

DEBUG_FLAGS+=$(DDEBUG)
DEBUG_FLAGS+=$(DDEBUG_SYMBOLS)
DEBUG_FLAGS+=$(DEXPORT_DYN)

COVOPT=--DRT-covopt=\"dstpath:$(DLOG)\"

DLIBTYPE=${if $(SHARED),$(DSHAREDLIB),$(DSTATICLIB)}

#DEBUGFLAG+=
env-compiler:
	$(PRECMD)
	${call log.header, $@ :: compiler}
	$(DC) --version | head -4
	${call log.kvp, DC, $(DC)}
	${call log.kvp, COMPILER, $(COMPILER)}
	${call log.kvp, ARCH, $(ARCH)}
	${call log.kvp, MODEL, $(MODEL)}
	${call log.kvp, OUTPUT, $(OUTPUT)}
	${call log.kvp, HF, $(HF)}
	${call log.kvp, DF, $(DF)}
	${call log.kvp, NO_OBJ, $(NO_OBJ)}
	${call log.kvp, DJSON, $(DJSON)}
	${call log.kvp, SONAME_FLAG, "$(SONAME_FLAG)"}
	${call log.kvp, DVERSION, $(DVERSION)}
	${call log.kvp, DDEBUG, $(DDEBUG)}
	${call log.kvp, DUNITTEST, $(DUNITTEST)}
	${call log.kvp, DMAIN, $(DMAIN)}
	${call log.kvp, DIP, $(DIP)}
	${call log.kvp, DIP25, $(DIP25)}
	${call log.kvp, DIP1000, $(DIP1000)}
	${call log.kvp, DPREVIEW, $(DPREVIEW)}
	${call log.kvp, DFPIC, $(DFPIC)}
	${call log.kvp, DCOMPILE_ONLY, $(DCOMPILE_ONLY)}
	${call log.kvp, DBETTERC, $(DBETTERC)}
	${call log.kvp, DDEBUG_SYMBOLS , $(DDEBUG_SYMBOLS)}
	${call log.kvp, DEXPORT_DYN, $(DEXPORT_DYN)}
	${call log.kvp, DCOV, $(DCOV)}
	${call log.kvp, DIMPORTFILE, $(DIMPORTFILE)}
	${call log.kvp, DEBUG_FLAGS, "$(DEBUG_FLAGS)"}
	${call log.kvp, DFLAGS, "$(DFLAGS)"}
	${call log.kvp, LDCFLAGS, "$(LDCFLAGS)"}
	${call log.kvp, SOURCEFLAGS, "$(SOURCEFLAGS)"}
	${call log.close}

env: env-compiler
