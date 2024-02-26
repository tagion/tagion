
env-tvm-sdk:
	$(PRECMD)
	$(call log.header, $@ :: env)
	$(call log.kvp, TVM_SDK_ROOT, $(TVM_SDK_ROOT))
	$(call log.kvp, TVM_SDK_TEST_ROOT, $(TVM_SDK_TEST_ROOT))
	$(call log.env, TVM_SDK_TESTS, $(TVM_SDK_TESTS))
	$(call log.env, TVM_SDK_DINC, $(TVM_SDK_DINC))
	$(call log.env, TVM_SDK_DFILES, $(TVM_SDK_DFILES))
	$(call log.close)

.PHONY: env-tvm

env: env-tvm-sdk

lib-tvm-sdk: $(DLIB)/libtagion.a

test-tvm-sdk: $(TVM_SDK_TESTS:.d=.wasm)

help-tvm-sdk:
	$(PRECMD)
	$(call log.header, $@ :: help)
	$(call log.close)

$(DBIN)/%.wasm: $(DOBJ)/%.o 
	echo WASM $@ $<

$(DOBJ)/%.o: $(TVM_SDK_TEST_ROOT)/%.d 
	echo DOBJ $@ $<

$(DLIB)/libtagion.a: $(TVM_SDK_DFILES)
	@echo $<
	@echo WASI_DFLAGS=$(WASI_DFLAGS)
	$(DC) $(WASI_DFLAGS) $(TVM_SDK_DINC) $(WASI_LDFALGS) $< $(OUTPUT)=$@ 

.PHONY: help-tvm-sdk

