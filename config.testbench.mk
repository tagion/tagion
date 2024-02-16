
COLLIDER_ROOT?=$(DLOG)/bdd/
BDD_FLAGS+=-p
BDD_FLAGS+=-i$(BDD)/bdd_import.di
BDD_FLAGS+=${addprefix -I,$(BDD)}

BDD_DFLAGS+=${addprefix -I,$(BDD)}

export BDD_LOG=$(DLOG)/bdd/$(TEST_STAGE)/
export BDD_RESULTS=$(BDD_LOG)/results/

BDD_DFILES+=${shell find $(BDD) -name "*.d" -a -not -name "*.gen.d" -a -path "*/testbench/*" -a -not -path "*/unitdata/*" -a -not -path "*/backlog/*" }
testbench: DFILES+=${shell find $(DSRC)/bin-wave/ -name "*.d"}
testbench: DFILES+=${shell find $(DSRC)/bin-tagionshell/ -name "*.d"}
testbench: DFILES+=${shell find $(DSRC)/bin-geldbeutel/ -name "*.d"}
testbench: DFILES+=${shell find $(DSRC)/bin-stiefel/ -name "*.d"}

testbench: DINC+=$(DSRC)/bin-wave/
testbench: DINC+=$(DSRC)/bin-tagionshell/
testbench: DINC+=$(DSRC)/bin-stiefel/

#
# Binary testbench 
#
testbench: bddfiles
target-testbench: nng secp256k1
target-testbench: DFLAGS+=$(DVERSION)=ONETOOL
target-testbench: LDFLAGS+=$(LD_SECP256K1) $(LD_NNG)
target-testbench: DFLAGS+=$(DEBUG_FLAGS)

${call DO_BIN,testbench,$(LIB_DFILES) $(BDD_DFILES)}
