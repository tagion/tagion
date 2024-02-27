
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

test32: $(DBIN)/$(TVM_SDK_TESTS:.d=.wasm)

help-tvm-sdk:
	$(PRECMD)
	$(call log.header, $@ :: help)
	$(call log.close)

$(DLIB)/libtagion.a: DFLAGS+=$(DCOMPILE_ONLY)

$(DLIB)/libtagion.a: $(TVM_SDK_DFILES)
	$(PRECMD)
	echo lib $<
	echo $<
	$(call log.env, DFLAGS, $(DFLAGS))
	$(call log.env, DFILES, $(DFILES))
	$(call WASI_LDFALGS, $(WASI_LDFALGS))
	echo DC=$(DC)
	$(DC) $(DFLAGS)  $(TVM_SDK_DINC) $(WASI_LDFALGS)  $< $(OUTPUT)=$@ 

.PHONY: help-tvm-sdk
