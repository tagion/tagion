
TVM_SDK_BINS=$(addprefix $(DBIN)/,$(TVM_SDK_TESTS:.d=.wasm))
LIBTVM=$(DLIB)/libtauon.a

env-tauon:
	$(PRECMD)
	$(call log.header, $@ :: env)
	$(call log.kvp, TVM_SDK_ROOT, $(TVM_SDK_ROOT))
	$(call log.kvp, TVM_SDK_TEST_ROOT, $(TVM_SDK_TEST_ROOT))
	$(call log.kvp, LIBEXT, $(LIBEXT))
	$(call log.kvp, WASI_SYSROOT, $(WASI_SYSROOT))
	$(call log.env, TVM_SDK_TESTS, $(TVM_SDK_TESTS))
	$(call log.env, TVM_SDK_BINS, $(TVM_SDK_BINS))
	$(call log.env, TVM_SDK_DINC, $(TVM_SDK_DINC))
	$(call log.env, TVM_SDK_DFILES, $(TVM_SDK_DFILES))
	$(call log.close)

.PHONY: env-tauon

env: env-tauon


#lib-tauon: $(LIBTVM)

$(DLIB)/libdruntime-ldc.a:
	$(MAKE) -C $(WASI_DRUNTIME_ROOT) TARGET_DIR=$(DBUILD) libdruntime 

$(DLIB)/libdphobos2-ldc.a:
	$(MAKE) -C $(WASI_DRUNTIME_ROOT) TARGET_DIR=$(DBUILD) libphobos2 

$(DLIB)/libtauon.a: DFILES+=$(TVM_SDK_DFILES)
$(DLIB)/libtauon.a: DINC+=$(TVM_SDK_DINC)
$(DLIB)/libtauon.a: $(DLIB)/.way 

$(DBIN)/tvm_sdk_test.wasm: DINC+=$(TVM_SDK_DINC)
$(DBIN)/tvm_sdk_test.wasm: LIB+=$(WASI_LIB)
$(DBIN)/tvm_sdk_test.wasm: LIB+=$(LIBTVM)
$(DBIN)/tvm_sdk_test.wasm: $(DBIN)/.way

$(DOBJ)/wasi/tests/tvm_sdk_test.o: DINC+=$(TVM_SDK_DINC)

tauon-test: $(DLIB)/libtauon.a
tauon-test: $(DLIB)/libdruntime-ldc.a
tauon-test: $(DLIB)/libdphobos2-ldc.a
tauon-test: $(TVM_SDK_BINS)

help-tauon:
	$(PRECMD)
	$(call log.header, $@ :: help)
	$(call log.close)

#$(DBIN)/%.wasm: |$(DLIB)/libtauon.a $(DLIB)/libdruntime-ldc.a $(DLIB)/libdphobos2-ldc.a 

$(DBIN)/%.wasm: $(DOBJ)/wasi/tests/%.o
	@echo $@
	@echo $*
	@echo $<
	@echo $(DOBJ)/$*
	$(WASMLD) $(LIB) $< $(WASI_LDFLAGS) -o $@

.PHONY: help-tauon

clean-tauon:
	$(PRECMD)
	$(call log.header, $@ :: clean)
	$(RM) $(LIBTVM)
	$(RMDIR) $(DBUILD)
	
.PHONY: clean-tauon

clean: clean-tauon


