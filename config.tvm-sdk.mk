
TVM_SDK_ROOT:=$(abspath $(REPOROOT)/tvm)
TVM_SDK_TEST_ROOT:=$(abspath $(TVM_SDK_ROOT)/tests)	
#TVM_SDK_TEST+=$(REPOROOT)/foundation/tests

TVM_SDK_TESTS!=find $(TVM_SDK_TEST_ROOT) -name "*.d"

