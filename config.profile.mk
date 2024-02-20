ifeq ($(DC),ldc2)
DPROFILE+=-fprofile-instr-generate
#DPROFILE+=-fprofile-instr-use=tagion.profraw
#DPROFILE+=-fdmd-trace-functions
#DPROFILE+=--fprofile-generate
#DPROFILE+=-ftime-trace
#DPROFILE+=-ftime-trace-file=trace.json
else ifeq ($(DC),dmd)
DPROFILE+=-profile
#DPROFILE+=-profile=gc
endif

ifdef PROFILE
DFLAGS+=$(DPROFILE)
endif

