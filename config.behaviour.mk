
BDD_FLAGS+=-p
BDD_FLAGS+=-i$(BDD)/bdd_import.di
BDD_FLAGS+=${addprefix -I,$(BDD)}


BDD_DFLAGS+=${addprefix -I,$(BDD)}

BDD_LOG=$(DLOG)/bdd

BDD_DFILES+=${shell find $(BDD) -type f -name "*.d" -path "*/tagion/*" -a -not -name "*.gen.d"}
#BDD_DFILES+=${shell find $(BDD) -type f -name "*.d" -path "*/tests/*"}

target-bdd_testbench: DFLAGS+=$(BDD_DFLAGS)
target-bdd_testbench: DFILES+=$(BDD_DFILES)

target-bdd_testbench: 
${call DO_BIN,bdd_testbench,$(LIBOPENSSL) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)}

BDDTESTS+=bdd_services


