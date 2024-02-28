
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
#$(DLIB)/libtvm.a: DFILES+=$(DSRC)/wasi/
$(DLIB)/libtvm.a: DINC+=$(TVM_SDK_DINC)
$(DLIB)/libtvm.a: $(DLIB)/.way 

#$(DBIN)/tvm_sdk_test.wasm: DFILES+=$(TVM_SDK_ROOT)/tvm/wasi_main.d

#$(DBIN)/tvm_sdk_test.wasm: DFILES+=$(TVM_SDK_TEST_ROOT)/tvm_sdk_test.d

$(DBIN)/tvm_sdk_test.wasm: DINC+=$(TVM_SDK_DINC)

$(DBIN)/tvm_sdk_test.wasm: LIB+=$(WASI_LIB)
$(DBIN)/tvm_sdk_test.wasm: LIB+=$(DLIB)/libtvm.a
#$(DBIN)/tvm_sdk_test.wasm: LIB+=$(WASI_LIB)

$(DOBJ)/wasi/tests/tvm_sdk_test.o: DINC+=$(TVM_SDK_DINC)

test32: $(DBIN)/$(TVM_SDK_TESTS:.d=.wasm)

test33: $(DOBJ)/wasi/tests/tvm_sdk_test.o

test34:
	echo $(OBJEXT)

test36: $(DLIB)/libdruntime-ldc.a
test36: $(DLIB)/libdphobos2-ldc.a
test36: $(DBIN)/tvm_sdk_test.wasm 

help-tvm-sdk:
	$(PRECMD)
	$(call log.header, $@ :: help)
	$(call log.close)

ifdef DONT
$(DLIB)/libtvm.a: DFLAGS+=$(DCOMPILE_ONLY)


$(DLIB)/libtvm.a: $(TVM_SDK_DFILES)
	$(PRECMD)
	echo lib $<
	echo $<
	$(call log.kvp, LIBEXT, $(LIBEXT))
	$(call log.env, DFLAGS, $(DFLAGS))
	$(call log.env, DFILES, $(DFILES))
	$(call log.env, LDFLAGS, $(LDFLAGS))
	echo DC=$(DC)
	$(DC) $(DFLAGS)  $(TVM_SDK_DINC)   $< $(OUTPUT)=$@ 

$(DOBJ)/%.o: 
	@echo $@ 
	@echo $(DSRC)/$*.d
	@echo $<
	$(DC) $(addprefix -I,$(TVM_SDK_DINC)) $(DFLAGS) $(WASI_LIB) $< $(OUTPUT)=$@
endif

test45:
	@echo $(DOBJ)
	@echo $(DOBJ)/wasi/tests/tvm_sdk_test.o 
	@echo $(DSRC)
	@echo $(DSRC)/wasi/tests/tvm_sdk_test.d 

$(DBIN)/%.wasm: |$(DLIB)/libtvm.a $(DLIB)/libdruntime-ldc.a $(DLIB)/libdphobos2-ldc.a 

$(DBIN)/%.wasm: $(DOBJ)/wasi/tests/%.o
	@echo $@
	@echo $*
	@echo $<
	@echo $(DOBJ)/$*
	$(WASMLD) $(LIB) $< $(WASI_LDFLAGS) -o $@

ifdef DONT
$(DBIN)/%.wasm: $(DOBJ)/%.o
	$(call log.env, WASI_LIB, $(WASI_LIB))
	$(WASMLD) $(addprefix -I,$(TVM_SDK_DINC)) $(WASI_LIB) $(DFLAGS) $(DFILES) -o $@
endif

.PHONY: help-tvm-sdk

clean-tvm-sdk:
	$(PRECMD)
	$(call log.header, $@ :: clean)
	echo WASI_LIB=$(WASI_LIB)
	echo LIBTVM=$(LIBTVM)
	$(RM) $(LIBTVM)

.PHONY: clean-tvm-sdk

clean: clean-tvm-sdk


