
SOURCE:=hibon
-include dfiles.mk
ifndef DFILES
prepare: dfiles.mk
endif

DC?=dmd
#DFLAGS+=-betterC
<<<<<<< HEAD
DFLAGS+=-I$(BETTERCREPOROOT)
=======
DFLAGS+=-I$(REPOROOT)
>>>>>>> 4f386fd9a5d04e3a5776a225aa91fba2a399caaa

TESTFLAGS+=$(DFLAGS)
TESTFLAGS+=-unittest
TESTFLAGS+=-g
TESTFLAGS+=-debug
# Enables memtrace dump
#TESTFLAGS+=-version=memtrace

UNITTEST:=tests/unittest.d

<<<<<<< HEAD
BIN:=$(BETTERCROOT)/bin/
=======
BIN:=$(REPOROOT)/bin/
>>>>>>> 4f386fd9a5d04e3a5776a225aa91fba2a399caaa

TEST:=$(BIN)/unittest
