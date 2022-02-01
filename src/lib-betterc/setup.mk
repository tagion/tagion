
SOURCE:=hibon
-include dfiles.mk
ifndef DFILES
prepare: dfiles.mk
endif

DC?=dmd
#DFLAGS+=-betterC
DFLAGS+=-I$(REPOROOT)

TESTFLAGS+=$(DFLAGS)
TESTFLAGS+=-unittest
TESTFLAGS+=-g
TESTFLAGS+=-debug
# Enables memtrace dump
#TESTFLAGS+=-version=memtrace

UNITTEST:=tests/unittest.d

BIN:=$(REPOROOT)/bin/

TEST:=$(BIN)/unittest
