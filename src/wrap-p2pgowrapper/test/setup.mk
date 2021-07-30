
include ${REPOROOT}/setup.mk
ifndef NOUNITTEST
DCFLAGS+=-unittest
endif
DCFLAGS+=$(DEBUG)
DCFLAGS+=-g
# This means that the network does not work with member lists
# So new public key is added auto matically

DTEST:=dtest

MAIN+=$(DTEST)
WORKDIR:=$(REPOROOT)/test


LDCFLAGS+=$(LIBRARY)
LDCFLAGS+=$(GOLIBP2P)


#.PHONY: lib-p2p

#OBJS:=libtagion.a
help: help-main
	@echo "make all       : Compiles $(MAIN) programs"
#	@echo
#	@echo "make run       : Compiles and runs the test"
	@echo
	@echo "make dtest"
	@echo
	@echo "make clean     : clean the testcase"
	@echo
	@echo "make COV=1 ..  : Switches on the code covarage"
	@echo

run: lib-p2p $(DTEST)
	./$(DTEST)

lib-p2p:
	$(MAKE) -C .. lib
