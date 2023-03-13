
TESTMAIN?=testbench

BDDS+=ssl_echo_server # acceptance
BDDS+=transaction # acceptance
BDDS+=transaction_mode_zero # acceptance
BDDS+=receive_epoch # acceptance
BDDS+=dart_test # commit
BDDS+=dart_deep_rim_test # commit
BDDS+=dart_pseudo_random_archives # commit
BDDS+=dart_sync # commit
BDDS+=dart_partial_sync # commit
BDDS+=dart_stress # performance

run-ssl_echo_server: sslextras

run-ssl_server: sslextras
run-ssl_server: RUNFLAGS+=$(BDD)/tagion/testbench/network/tagionwave.json


include $(BDD)/context.mk




