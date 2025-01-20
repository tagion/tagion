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
DOPT    = -O2
LINKERFLAG= -Xlinker
DOUT  = -o
HF      = -fintfc-file=
DF      = -fdoc-file=
NO_OBJ	= -fsyntax-only
DDOC_MACRO= -fdoc-inc=
else ifeq ($(COMPILER),ldc)
DOPT    = -O3
LINKERFLAG= -L
DOUT  = -of
HF      = -Hf
DF      = -Df
DD      = -Dd
DDOC_MACRO=
else
DOPT    = -O
LINKERFLAG=-L
DOUT  = -of
HF      = -Hf
DF      = -Df
DD      = -Dd
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
DCOV=--cov
DIMPORTFILE=-J
DDEFAULTLIBSTATIC=-link-defaultlib-shared=false
DINCIMPORT=-i
DSTATICLIB=--lib
DSHAREDLIB=--shared
DOUTDIR = --od
FULLY_QUALIFIED = -oq
DDEBUG_DEFAULTLIB::=--link-defaultlib-debug
DWARNERROR::=-w
DWARNINFO::=--wi
CPP_FLAG := -P
GEN_CPP_HEADER_FILE::=--HCf
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
DOUTDIR = -od
CPP_FLAG := -P
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
DOUTDIR = -od
VERRORS=-verrors=context
DWARNERROR::=-w
DWARNINFO::=-wi
GEN_CPP_HEADER_FILE::=-HCf
endif

DIP1000 := $(DIP)1000

# Define relocation model for ldc or other
ifeq ($(COMPILER),ldc)
# FPIC = -relocation-model=pic
else
# FPIC = -fPIC
endif

INCLFLAGS := ${addprefix -I,${shell ls -d $(DSRC)/*/ 2> /dev/null || true | grep -v wrap-}}

DDEBUG_FLAGS+=$(DDEBUG)
ifdef SYMBOLS_ENABLE
DDEBUG_FLAGS+=$(DDEBUG_SYMBOLS)
DDEBUG_FLAGS+=$(DDEBUG_DEFAULTLIB)
endif

ifdef RELEASE
DFLAGS+=$(RELEASE_DFLAGS)
endif

ifdef DEBUG_ENABLE
DFLAGS+=$(DDEBUG_FLAGS)
LDFLAGS+=$(LD_EXPORT_DYN)
else
LDFLAGS+=$(LD_STRIP)
endif

ifdef WARNINGS
ifeq ($(WARNINGS),ERROR)
DFLAGS+=$(DWARNERROR)
else ifeq ($(WARNINGS),INFO)
DFLAGS+=$(DWARNINFO)
else # ifeq INFO
DFLAGS+=$(DWARNINFO)
endif
endif # ifdef WARNINGS

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
	${call log.kvp, DOUT, $(DOUT)}
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
	${call log.kvp, DINCIMPORT, $(DINCIMPORT)}
	${call log.kvp, DFPIC, $(DFPIC)}
	${call log.kvp, DCOMPILE_ONLY, $(DCOMPILE_ONLY)}
	${call log.kvp, DBETTERC, $(DBETTERC)}
	${call log.kvp, DDEBUG_SYMBOLS , $(DDEBUG_SYMBOLS)}
	${call log.kvp, DEXPORT_DYN, $(DEXPORT_DYN)}
	${call log.kvp, DCOV, $(DCOV)}
	${call log.kvp, DIMPORTFILE, $(DIMPORTFILE)}
	${call log.line}
	${call log.kvp, DEBUG_ENABLE, $(DEBUG_ENABLE)}
	${call log.kvp, DDEBUG_FLAGS, "$(DDEBUG_FLAGS)"}
	${call log.kvp, DFLAGS, "$(DFLAGS)"}
	${call log.kvp, DVERSIONS, "$(DVERSIONS)"}
	${call log.kvp, DDEBUG_VERSIONS, "$(DDEBUG_VERSIONS)"}
	${call log.close}

env: env-compiler

DC_VERSION_NUMBER=${shell $(DC) --version | $(DTUB)/tool_version.pl}

test34:
	echo $(DC_VERSION_NUMBER) 

