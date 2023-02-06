
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



