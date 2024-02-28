
env-tvm-sdk:
	$(PRECMD)
	$(call log.header, $@ :: env)
	$(call log.kvp, TVM_SDK_ROOT, $(TVM_SDK_ROOT))
	$(call log.kvp, TVM_SDK_TEST_ROOT, $(TVM_SDK_TEST_ROOT))
	$(call log.kvp, LIBEXT, $(LIBEXT))
	$(call log.env, TVM_SDK_TESTS, $(TVM_SDK_TESTS))
	$(call log.env, TVM_SDK_DINC, $(TVM_SDK_DINC))
	$(call log.env, TVM_SDK_DFILES, $(TVM_SDK_DFILES))
	$(call log.env, WASI_SYSROOT, $(WASI_SYSROOT))
	$(call log.close)

.PHONY: env-tvm

env: env-tvm-sdk

LIBTVM=$(DLIB)/libtvm.a

lib-tvm-sdk: $(LIBTVM)

$(DLIB)/libdruntime-ldc.a:
	$(MAKE) -C $(WASI_DRUNTIME_ROOT) TARGET_DIR=$(DBUILD) libdruntime 

$(DLIB)/libdphobos2-ldc.a:
	$(MAKE) -C $(WASI_DRUNTIME_ROOT) TARGET_DIR=$(DBUILD) libphobos2 

$(DLIB)/libtvm.a: DFILES+=$(TVM_SDK_DFILES)
$(DLIB)/libtvm.a: DINC+=$(TVM_SDK_DINC)
$(DLIB)/libtvm.a: $(DLIB)/.way 

$(DBIN)/tvm_sdk_test.wasm: DINC+=$(TVM_SDK_DINC)
$(DBIN)/tvm_sdk_test.wasm: LIB+=$(WASI_LIB)
$(DBIN)/tvm_sdk_test.wasm: LIB+=$(LIBTVM)
$(DBIN)/tvm_sdk_test.wasm: $(DBIN)/.way

$(DOBJ)/wasi/tests/tvm_sdk_test.o: DINC+=$(TVM_SDK_DINC)

test36: $(DLIB)/libtvm.a
test36: $(DLIB)/libdruntime-ldc.a
test36: $(DLIB)/libdphobos2-ldc.a
test36: $(DBIN)/tvm_sdk_test.wasm 

help-tvm-sdk:
	$(PRECMD)
	$(call log.header, $@ :: help)
	$(call log.close)

$(DBIN)/%.wasm: |$(DLIB)/libtvm.a $(DLIB)/libdruntime-ldc.a $(DLIB)/libdphobos2-ldc.a 

$(DBIN)/%.wasm: $(DOBJ)/wasi/tests/%.o
	@echo $@
	@echo $*
	@echo $<
	@echo $(DOBJ)/$*
	$(WASMLD) $(LIB) $< $(WASI_LDFLAGS) -o $@

.PHONY: help-tvm-sdk

clean-tvm-sdk:
	$(PRECMD)
	$(call log.header, $@ :: clean)
	$(RM) $(LIBTVM)
	$(RMDIR) $(DBUILD)
	
.PHONY: clean-tvm-sdk

clean: clean-tvm-sdk


