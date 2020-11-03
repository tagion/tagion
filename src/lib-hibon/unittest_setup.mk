UNITTEST:=$(BIN)/uinttest

#DFILES+=$(WAVM_DI)
#TESTDCFLAGS+=$(WAVM_DI)
#TESTDCFLAGS+=-I$(REPOROOT)/tests/basic/d/
TESTDCFLAGS+=$(LIBS)
#TESTDCFLAGS+=$(TAGION_CORE)/bin/libtagion.a
TESTDCFLAGS+=$(TAGION_DFILES)
#TESTDCFLAGS+=$(REPOROOT)/tests/basic/d/src/native_impl.d
#TESTDCFLAGS+=$(REPOROOT)/tests/unittest.d
TESTDCFLAGS+=-main

vpath %.d tests/
