
BDD_FLAGS+=-i$(BDD)/bdd_import.di
BDD_FLAGS+=${addprefix -I,$(BDD)}

BDD_DFLAGS+=${addprefix -I,$(BDD)}

BDD_LOG=$(DLOG)/bdd

BDD_DFILES+=${shell find $(BDD) -type f -name "*.d" -path "*/tagion/*" -a -not -name "*.gen.d"}
BDD_DFILES+=${shell find $(BDD) -type f -name "*.d" -path "*/tests/*"}

target-bdd_test: DFLAGS+=$(BDD_DFLAGS)
target-bdd_test: DFILES+=$(BDD_DFILES)

target-bdd_test: 
${call DO_BIN,bdd_test,$(LIBOPENSSL) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)}

BDDTESTS+=bdd_test

