# If compiler is not defined, try to find it
ifndef DC
DC!=which ldc2||which dmd||which gdc
endif

# Define a compiler family for other conditionals
ifeq ($(notdir $(DC)),gdc)
COMPILER=gdc
else ifeq ($(notdir $(DC)),gdmd)
COMPILER=dmd
else ifeq ($(notdir $(DC)),ldc)
COMPILER=ldc
else ifeq ($(notdir $(DC)),ldc2)
COMPILER=ldc
else ifeq ($(notdir $(DC)),ldmd)
COMPILER=ldc
else ifeq ($(notdir $(DC)),dmd)
COMPILER=dmd
else ifeq ($(notdir $(DC)),dmd2)
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
DINCIMPORT=-i
DSTATICLIB=--lib
DSHAREDLIB=--shared
OUTPUTDIR = --od
FULLY_QUALIFIED = -oq
else ifeq ($(COMPILER),gdc)
DVERSION := -fversion
SONAME_FLAG := $(LINKERFLAG)-soname
DDEBUG := -fdebug
DUNITTEST := -funittest
DMAIN := -fmain
DIP := -fpreview=dip
DIMPORTFILE=-J
DDEBUG_SYMBOLS := -g
DBETTERC := --betterC
DCOMPILE_ONLY := -c
DPREVIEW :=-preview
NO_OBJ ?= -o-
DCOV ?=-cov
DINCIMPORT=-i
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
DINCIMPORT=-i
DSTATICLIB=-lib
DSHAREDLIB=-shared
OUTPUTDIR = -od
VERRORS=-verrors=context
endif

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

INCLFLAGS := ${addprefix -I,${shell ls -d $(DSRC)/*/ 2> /dev/null || true | grep -v wrap-}}

DEBUG_FLAGS+=$(DDEBUG)
DEBUG_FLAGS+=$(DDEBUG_SYMBOLS)

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
	${call log.kvp, DOPT, $(DOPT)}
	${call log.kvp, DUNITTEST, $(DUNITTEST)}
	${call log.kvp, LINKERFLAG, $(LINKERFLAG)}
	${call log.kvp, DMAIN, $(DMAIN)}
	${call log.kvp, DIP, $(DIP)}
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
