
TESTMAIN?=testbench

BDDS+=bdd_wallets
BDDS+=sslserver
BDDS+=ssl_echo_server

run-sslserver: sslextras
run-sslserver: RUNFLAGS+=$(BDD)/tagion/testbench/network/tagionwave.json


include $(BDD)/context.mk




