
TESTMAIN?=testbench

BDDS+=bdd_wallets
BDDS+=ssl_echo_server
BDDS+=ssl_server

run-ssl_echo_server: sslextras

run-ssl_server: sslextras
run-ssl_server: RUNFLAGS+=$(BDD)/tagion/testbench/network/tagionwave.json


include $(BDD)/context.mk




