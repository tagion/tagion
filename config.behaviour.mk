
BDD_FLAGS+=-i$(BDD)/bdd_import.di
BDD_FLAGS+=${addprefix -I,$(BDD)}

BDD_DFLAGS+=${addprefix -I,$(BDD)}

BDD_LOG=$(DLOG)/bdd

BDD_DFILES+=${shell find $(BDD) -type f -name "*.d" -path "*/tagion/*" -a -not -name "*.gen.d"}
BDD_DFILES+=${shell find $(BDD) -type f -name "*.d" -path "*/bin/*"}

target-bdd_test: DFLAGS+=$(BDD_DFLAGS)

target-bdd_test: 
${call DO_BIN,bdd_test,BDD_TEST,$(LIBOPENSSL) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)}

BDDTESTS+=bdd_test

