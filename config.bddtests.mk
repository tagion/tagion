
TESTMAIN?=testbench

BDDS+=ssl_echo_server
BDDS+=ssl_server
BDDS+=transaction

run-ssl_echo_server: sslextras

run-ssl_server: sslextras
run-ssl_server: RUNFLAGS+=$(BDD)/tagion/testbench/network/tagionwave.json


include $(BDD)/context.mk




