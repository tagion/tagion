UNITTEST:=$(BINDIR)/uinttest_$(PACKAGE)

TESTDCFLAGS+=$(LIBS)
TESTDCFLAGS+=-main
TESTDCFLAGS+=-g

#vpath %.d tests/
