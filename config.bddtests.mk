
TESTMAIN?=testbench

BDDS+=bdd_wallets
BDDS+=sslserver

run-sslserver: sslextras
run-sslserver: RUNFLAGS+=$(BDD)/tagion/testbench/network/tagionwave.json


include $(BDD)/context.mk




