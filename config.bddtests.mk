
TESTMAIN?=testbench

BDDS+=bdd_wallets
BDDS+=sslserver

run-sslserver: RUNFLAGS+=$(BDD)/tagion/testbench/network/tagionwave.json




