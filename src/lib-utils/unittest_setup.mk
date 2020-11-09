UNITTEST:=$(BINDIR)/uinttest_$(PACKAGE)

TESTDCFLAGS+=$(LIBS)
TESTDCFLAGS+=-main

#vpath %.d tests/
