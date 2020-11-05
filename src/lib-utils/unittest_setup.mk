UNITTEST:=$(BIN)/uinttest

TESTDCFLAGS+=$(LIBS)
TESTDCFLAGS+=-main

vpath %.d tests/
