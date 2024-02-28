
TVM_SDK_ROOT:=$(abspath $(DSRC)/wasi)
TVM_SDK_TEST_ROOT:=$(abspath $(TVM_SDK_ROOT)/tests)
#TVM_SDK_TEST+=$(REPOROOT)/foundation/tests

TVM_SDK_TESTS+=tvm_sdk_test.d

TVM_SDK_DINC+=$(TVM_SDK_ROOT)

TVM_SDK_DINC+=$(DSRC)/lib-basic
TVM_SDK_DINC+=$(DSRC)/lib-hibon
TVM_SDK_DINC+=$(DSRC)/lib-phobos
TVM_SDK_DINC+=$(DSRC)/lib-utils

TVM_SDK_DFILES+=$(DSRC)/wasi/tvm/wasi_main.d

TVM_SDK_DFILES+=$(DSRC)/lib-basic/tagion/basic/basic.d
TVM_SDK_DFILES+=$(DSRC)/lib-basic/tagion/basic/Version.d
TVM_SDK_DFILES+=$(DSRC)/lib-hibon/tagion/hibon/Document.d
TVM_SDK_DFILES+=$(DSRC)/lib-hibon/tagion/hibon/HiBONRecord.d
TVM_SDK_DFILES+=$(DSRC)/lib-hibon/tagion/hibon/HiBON.d
TVM_SDK_DFILES+=$(DSRC)/lib-hibon/tagion/hibon/HiBONBase.d
#TVM_SDK_DFILES+=$(DSRC)/lib-hibon/tagion/hibon/HiBON.d
#TVM_SDK_DFILES+=$(DSRC)/lib-hibon/tagion/hibon/HiBON.d

#TVM_SDK_DFILES+=$(DSRC)/lib-hibon/tagion/hibon/Version.d

