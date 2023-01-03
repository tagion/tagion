
test-dart: DARTDB=$(TESTLOG)/test-dart.drt
test-dart: dart

mode1-alpha: HOSTPORT=4020
mode1-alpha: TRANSACTIONPORT=10910
mode1-alpha: MONITORPORT=10920
mode1-alpha: DARTSYNC=false
mode1-alpha: DARTDB=$(TESTLOG)/mode1/dart-alpha.drt
mode1-alpha: DARTINIT=false
mode1-alpha: dart

MODE1_LIST+=alpha

mode1-beta: HOSTPORT=4001
mode1-beta: TRANSACTIONPORT=10911
mode1-beta: MONITORPORT=10921
mode1-beta: DARTSYNC=true
mode1-beta: DARTINIT=true
MODE1_LIST+=beta

mode1-gamma: HOSTPORT=4002
mode1-gamma: TRANSACTIONPORT=10912
mode1-gamma: MONITORPORT=10922
mode1-gamma: DARTSYNC=true
mode1-gamma: DARTINIT=true
MODE1_LIST+=gamma

mode1-delta: HOSTPORT=4003
mode1-delta: TRANSACTIONPORT=10913
mode1-delta: MONITORPORT=10923
mode1-delta: DARTSYNC=true
mode1-delta: DARTINIT=true
MODE1_LIST+=delta

mode1-epsilon: HOSTPORT=4004
mode1-epsilon: TRANSACTIONPORT=10914
mode1-epsilon: MONITORPORT=10924
mode1-epsilon: DARTSYNC=true
mode1-epsilon: DARTINIT=true
MODE1_LIST+=epsilon

mode1-zeta: HOSTPORT=4005
mode1-zeta: TRANSACTIONPORT=10915
mode1-zeta: MONITORPORT=10925
mode1-zeta: DARTSYNC=true
mode1-zeta: DARTINIT=true
MODE1_LIST+=zeta


mode1-eta: HOSTPORT=4006
mode1-eta: TRANSACTIONPORT=10916
mode1-eta: MONITORPORT=10926
mode1-eta: DARTSYNC=true
mode1-eta: DARTINIT=true
MODE1_LIST+=eta
