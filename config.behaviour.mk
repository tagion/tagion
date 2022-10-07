
BDD_FLAGS+=${addprefix -I,$(DINC)}

BDDFILES+=${shell find $(BDD) -type f -name "*.d" -path "*bdd/tagion/*" -a -not -name "*.gen.d"}

target-bdd_test: DFILES+=$(BDDFILES)
${call BIN,bdd_test,BDD_TEST,$(LIBOPENSSL) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)}
