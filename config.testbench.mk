
export COLLIDER_ROOT?=$(DLOG)/bdd/
BDD_FLAGS+=-p
BDD_FLAGS+=-i$(BDD)/bdd_import.di
BDD_FLAGS+=${addprefix -I,$(BDD)}

export BDD_LOG=$(DLOG)/bdd/$(TEST_STAGE)/

TESTBENCH::=$(DBIN)/testbench
$(TESTBENCH): revision
$(TESTBENCH): nng secp256k1
$(TESTBENCH): DINC+=${shell find $(DSRC) -maxdepth 1 -type d -path "*/src/bin-*" -or -path "*/src/lib-*"}
$(TESTBENCH): DINC+=bdd/
$(TESTBENCH): DFLAGS+=$(DVERSION)=ONETOOL
$(TESTBENCH): DFLAGS+=$(DVERSION)=BDD
$(TESTBENCH): LDFLAGS+=$(LD_SECP256K1) $(LD_NNG)
$(TESTBENCH): DFILES::=$(BDD)/tagion/testbench/testbench.d
$(TESTBENCH): $(shell find $(DSRC) -name "*.d")
$(TESTBENCH): $(shell find $(BDD) -name "*.d")
$(TESTBENCH): bddfiles
ifdef ENABLE_WASMER
$(TESTBENCH): libwasmer
$(TESTBENCH): LDFLAGS+=$(LD_WASMER)
endif

testbench: $(DBIN)/testbench
.PHONY: testbench
