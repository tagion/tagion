NO_UNITDATA=-a -not -path "*/unitdata/*"
EXCLUDED_DIRS+=-a -not -path "*/lib-betterc/*"
EXCLUDED_DIRS+=-a -not -path "*/tests/*"
EXCLUDED_DIRS+=-a -not -path "*/.dub/*"

LIB_DFILES=$(shell find $(DSRC) -name "*.d" -a -path "*/lib-*" $(EXCLUDED_DIRS) $(NO_UNITDATA) )

UNITTEST_FLAGS+=$(DUNITTEST) $(DDEBUG) $(DDEBUG_SYMBOLS) $(DMAIN)
UNITTEST_DFILES+=$(LIB_DFILES)
UNITTEST_DFILES+=$(DTUB)/unitmain.d

# newunitmain: DFLAGS+=$(UNITTEST) $(DDEBUG) $(DDEBUG_SYMBOLS) $(DMAIN)
