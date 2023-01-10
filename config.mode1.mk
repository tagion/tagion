
NODES?=7
NODE_LIST=${shell echo "echo {2..$(NODES)}" | bash}

test-dart: DARTDB=$(TESTLOG)/test-dart.drt
test-dart: dart

mode1-alpha: HOSTPORT=4000
mode1-alpha: TRANSACTIONPORT=10910
mode1-alpha: MONITORPORT=10920
mode1-alpha: DARTSYNC=false
mode1-alpha: DARTDB=$(TESTLOG)/mode1/dart-alpha.drt
mode1-alpha: DARTINIT=false
mode1-alpha: dart
MODE1_LIST+=alpha

define MODE1_NODE
${eval
mode1-beta_$1: HOSTPORT=`expr 4000 + $1`
mode1-beta_$1: TRANSACTIONPORT=`expr 10910 + $1`
mode1-beta_$1: MONITORPORT=`expr 10920 + $1`
mode1-beta_$1: DARTSYNC=true
mode1-beta_$1: DARTINIT=true
MODE1_LIST+=beta_$1

}
endef

${foreach node_no,$(NODE_LIST),${call MODE1_NODE,$(node_no)}}


ifdef YYY

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

ifdef EXTRANODES
mode1-eta_1: HOSTPORT=4007
mode1-eta_1: TRANSACTIONPORT=10917
mode1-eta_1: MONITORPORT=10927
mode1-eta_1: DARTSYNC=true
mode1-eta_1: DARTINIT=true
MODE1_LIST+=eta_1

mode1-eta_2: HOSTPORT=4008
mode1-eta_2: TRANSACTIONPORT=10918
mode1-eta_2: MONITORPORT=10928
mode1-eta_2: DARTSYNC=true
mode1-eta_2: DARTINIT=true
MODE1_LIST+=eta_2

mode1-eta_3: HOSTPORT=4009
mode1-eta_3: TRANSACTIONPORT=10919
mode1-eta_3: MONITORPORT=10929
mode1-eta_3: DARTSYNC=true
mode1-eta_3: DARTINIT=true
MODE1_LIST+=eta_3

mode1-eta_4: HOSTPORT=4010
mode1-eta_4: TRANSACTIONPORT=10920
mode1-eta_4: MONITORPORT=10930
mode1-eta_4: DARTSYNC=true
mode1-eta_4: DARTINIT=true
MODE1_LIST+=eta_4
endif
endif

