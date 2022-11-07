
BDD_FLAGS+=-p
BDD_FLAGS+=-i$(BDD)/bdd_import.di
BDD_FLAGS+=${addprefix -I,$(BDD)}


BDD_DFLAGS+=${addprefix -I,$(BDD)}

BDD_LOG=$(DLOG)/bdd

BDD_DFILES+=${shell find $(BDD) -type f -name "*.d" -path "*/tagion/*" -a -not -name "*.gen.d"}

target-bdd_services: LIBS+=$(LIBOPENSSL) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
target-bdd_services: DFLAGS+=$(BDD_DFLAGS)
target-bdd_services: DFILES+=$(BDD_DFILES)

${call DO_BIN,bdd_services}

BDDTESTS+=bdd_services


