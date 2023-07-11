
COLLIDER_ROOT?=$(DLOG)/bdd/
BDD_FLAGS+=-p
BDD_FLAGS+=-i$(BDD)/bdd_import.di
BDD_FLAGS+=${addprefix -I,$(BDD)}

BDD_DFLAGS+=${addprefix -I,$(BDD)}

export BDD_LOG=$(DLOG)/bdd/$(TEST_STAGE)/
export BDD_RESULTS=$(BDD_LOG)/results/

BDD_DFILES+=${shell find $(BDD) -name "*.d" -a -not -name "*.gen.d" -a -path "*/testbench/*" -a -not -path "*/unitdata/*" -a -not -path "*/backlog/*" $(NO_WOLFSSL) }

#
# Binary testbench 
#
testbench: bddfiles
target-testbench: DFLAGS+=$(DVERSION)=ONETOOL
target-testbench: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
target-testbench: DFLAGS+=$(DEBUG_FLAGS)

ifdef STLZMQ
target-testbench: LIBS+=$(LIBZMQ)
endif

${call DO_BIN,testbench,$(LIB_DFILES) $(BDD_DFILES)}



