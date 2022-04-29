
SOURCE:=tagion
-include $(BETTERCROOT)/gen.dfiles.mk
ifndef DFILES
prepare: gen.dfiles.mk
endif

DC?=dmd
#DFLAGS+=-betterC
DFLAGS+=-I$(BETTERCROOT)

TESTFLAGS+=$(DFLAGS)
TESTFLAGS+=-unittest
TESTFLAGS+=-g
TESTFLAGS+=-debug
# Enables memtrace dump
#TESTFLAGS+=-version=memtrace

UNITTEST:=tests/unittest.d

BIN:=$(BETTERCROOT)/bin/

TEST:=$(BIN)/unittest
