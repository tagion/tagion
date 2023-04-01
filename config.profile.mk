ifeq ($(DC),ldc2)
else ifeq ($(DC),dmd)
DPROFILE+=-profile
DPROFILE+=-profile=gc
endif

ifdef PROFILE
DFLAGS+=$(DPROFILE)
endif

