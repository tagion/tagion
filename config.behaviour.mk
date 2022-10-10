
BDD_FLAGS+=${addprefix -I,$(BDD)}

BDD_LOG=$(DLOG)/bdd

BDDFILES+=${shell find $(BDD) -type f -name "*.d" -path "*/tagion/*" -a -not -name "*.gen.d"}
BDDFILES+=${shell find $(BDD) -type f -name "*.d" -path "*/bin/*"}

target-bdd_test: DFILES+=$(BDDFILES)
${call BIN,bdd_test,BDD_TEST,$(LIBOPENSSL) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)}
