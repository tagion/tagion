
# Define command for copy, remove and create file/dir
ifeq ($(OS),"Windows")
    RM    = del /Q
    RMDIR = del /Q
    CP    = copy /Y
    MKDIR = mkdir
    MV    = move
    LN    = mklink
else ifeq ($(OS),"Linux")
    RM    = rm -f
    RMDIR = rm -rf
    CP    = cp -fr
    MKDIR = mkdir -p
    MV    = mv
    LN    = ln -s
else ifeq ($(OS),"FreeBSD")
    RM    = rm -f
    RMDIR = rm -rf
    MKDIR = mkdir -p
    MV    = mv
    LN    = ln -s
else ifeq ($(OS),"Solaris")
    RM    = rm -f
    RMDIR = rm -rf
    MKDIR = mkdir -p
    MV    = mv
    LN    = ln -s
else ifeq ($(OS),"Darwin")
    RM    = rm -f
    RMDIR = rm -rf
    MKDIR = mkdir -p
    MV    = mv
    LN    = ln -s
endif

# If compiler is not define try to find it
ifndef DC
    ifneq ($(strip $(shell which dmd 2>/dev/null)),)
        DC=dmd
    else ifneq ($(strip $(shell which ldc 2>/dev/null)),)
        DC=ldc
    else ifneq ($(strip $(shell which ldc2 2>/dev/null)),)
        DC=ldc2
    else
        DC=gdc
    endif
endif

#define a suufix lib who inform is build with which compiler
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

# Define flag for gdc other
ifeq ($(COMPILER),gdc)
    DFLAGS    = -O2
    LINKERFLAG= -Xlinker
    OUTPUT    = -o
    HF        = -fintfc-file=
    DF        = -fdoc-file=
    NO_OBJ    = -fsyntax-only
    DDOC_MACRO= -fdoc-inc=
else
    DFLAGS    = -O
    LINKERFLAG= -L
    OUTPUT    = -of
    HF        = -Hf
    DF        = -Df
    DD        = -Dd
    NO_OBJ    = -o-
    DDOC_MACRO=
endif


# Version statement / soname flag
ifeq ($(COMPILER),ldc)
    DVERSION    = -d-version
    SONAME_FLAG = -soname
    DEBUG       ?= -d-debug
    DIP         := --dip
else ifeq ($(COMPILER),gdc)
    DVERSION    = -fversion
    SONAME_FLAG = $(LINKERFLAG)-soname
    DEBUG       ?= -f-d-debug
    DIP         := unknown-dip
else
    DVERSION    = -version
    SONAME_FLAG = $(LINKERFLAG)-soname
    DEBUG       ?= -debug
    DIP         := -dip
endif

DIP1000 := $(DIP)1000
#DIP1021 := $(DIP)1021


# Define relocation model for ldc or other
ifeq ($(COMPILER),ldc)
    FPIC = -relocation-model=pic
else
    FPIC = -fPIC
endif

# Add -ldl flag for linux
ifeq ($(OS),"Linux")
    LDCFLAGS += $(LINKERFLAG)-ldl
endif

# If model are not given take the same as current system
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
ifndef MODEL
    ifeq ($(ARCH), x86_64)
        MODEL = 64
    else
        MODEL = 32
    endif
endif

ifeq ($(MODEL), 64)
    DFLAGS  += -m64
    LDCFLAGS += -m64
else
    DFLAGS  += -m32
    LDCFLAGS += -m32
endif
