
test-dart: DARTDB=$(TESTBENCH)/test-dart.drt
test-dart: dart

mode1-alpha: HOSTPORT=4020
mode1-alpha: TRANSACTIONPORT=10810
mode1-alpha: MONITORPORT=10820
mode1-alpha: DARTSYNC=false
mode1-alpha: DARTDB=$(TESTBENCH)/mode1/dart-alpha.drt
mode1-alpha: dart

MODE1_LIST+=alpha

mode1-beta: HOSTPORT=4021
mode1-beta: TRANSACTIONPORT=10811
mode1-beta: MONITORPORT=10821
mode1-beta: DARTSYNC=true
MODE1_LIST+=beta

mode1-gamma: HOSTPORT=4022
mode1-gamma: TRANSACTIONPORT=10812
mode1-gamma: MONITORPORT=10822
mode1-gamma: DARTSYNC=true
MODE1_LIST+=gamma

mode1-delta: HOSTPORT=4023
mode1-delta: TRANSACTIONPORT=10813
mode1-delta: MONITORPORT=10823
mode1-delta: DARTSYNC=true
MODE1_LIST+=delta

mode1-epsilon: HOSTPORT=4024
mode1-epsilon: TRANSACTIONPORT=10814
mode1-epsilon: MONITORPORT=10824
mode1-epsilon: DARTSYNC=true
MODE1_LIST+=epsilon

mode1-zeta: HOSTPORT=4025
mode1-zeta: TRANSACTIONPORT=10815
mode1-zeta: MONITORPORT=10825
mode1-zeta: DARTSYNC=true
MODE1_LIST+=zeta


mode1-eta: HOSTPORT=4026
mode1-eta: TRANSACTIONPORT=10816
mode1-eta: MONITORPORT=10826
mode1-eta: DARTSYNC=true
MODE1_LIST+=eta
