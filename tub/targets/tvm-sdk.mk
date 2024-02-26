


test88:
	echo $(REPOROOT)
	echo WASI_BIN=$(WASI_BIN)


env-tvm:
	$(PRECMD)
	$(call log.header, $@ :: env)
	$(call log.kvp, TVM_SDK_ROOT, $(TVM_SDK_ROOT))
	$(call log.kvp, TVM_SDK_TEST_ROOT, $(TVM_SDK_TEST_ROOT))
	$(call log.env, TVM_SDK_TESTS, $(TVM_SDK_TESTS))
	$(call log.close)

.PHONY: env-tvm

env: env-tvm

help-tvm:
	$(PRECMD)
	$(call log.header, $@ :: help)
	$(call log.close)


.PHONY: help-tvm

help: help-tvm


