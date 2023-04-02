ifeq ($(DC),ldc2)
DPROFILE+=--fprofile-generate
else ifeq ($(DC),dmd)
DPROFILE+=-profile
#DPROFILE+=-profile=gc
endif

ifdef PROFILE
DFLAGS+=$(DPROFILE)
endif

