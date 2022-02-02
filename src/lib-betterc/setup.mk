
SOURCE:=hibon
-include dfiles.mk
ifndef DFILES
prepare: dfiles.mk
endif

DC?=dmd
#DFLAGS+=-betterC
DFLAGS+=-I$(BETTERCREPOROOT)

TESTFLAGS+=$(DFLAGS)
TESTFLAGS+=-unittest
TESTFLAGS+=-g
TESTFLAGS+=-debug
# Enables memtrace dump
#TESTFLAGS+=-version=memtrace

UNITTEST:=tests/unittest.d

BIN:=$(BETTERCROOT)/bin/

TEST:=$(BIN)/unittest
