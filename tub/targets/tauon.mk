
TAUON_BINS=$(addprefix $(DBIN)/,$(TAUON_TESTS:.d=.wasm))
LIBTVM=$(DLIB)/libtauon.a

$(DLIB)/libdruntime-ldc.a: $(DLIB)/.way
	$(MAKE) -C $(WASI_DRUNTIME_ROOT) TARGET_DIR=$(DBUILD) libdruntime 

$(DLIB)/libdphobos2-ldc.a: $(DLIB)/.way
	$(MAKE) -C $(WASI_DRUNTIME_ROOT) TARGET_DIR=$(DBUILD) libphobos2 

$(DLIB)/libtauon.a: DFILES+=$(TAUON_DFILES)
#$(DLIB)/libtauin.a: DFILES+=--output-o
$(DLIB)/libtauon.a: DFLAGS+=--oq
$(DLIB)/libtauon.a: DFLAGS+=--od=$(DOBJ)
$(DLIB)/libtauon.a: DINC+=$(TAUON_DINC)
$(DLIB)/libtauon.a: DFLAGS+=-d-debug
$(DLIB)/libtauon.a: $(DLIB)/.way 

$(TAUON_BINS): $(DBIN)/.way

tauon-test: $(DLIB)/libtauon.a
tauon-test: $(DLIB)/libdruntime-ldc.a
tauon-test: $(DLIB)/libdphobos2-ldc.a
tauon-test: $(LIBSECP256K1)
tauon-test: LIB+=$(WASI_LIB)
tauon-test: LIB+=$(LIBTVM)
tauon-test: LIB+=$(LIBSECP256K1)
tauon-test: DINC+=$(TAUON_DINC)
tauon-test: $(TAUON_BINS)
tauon-test: DFLAGS+=-d-debug
#tauon-test: DFLAGS+=-L-error-limit=100
tauon-test: DFLAGS+=-L--no-entry
tauon-test: DFLAGS+=-L--lto-O2
tauon-test: DFLAGS+=--O2
#tauon-test: DFLAGS+=-L--initial-memory=16777216
#tauon-test: DFLAGS+=-L--max-memory=1024
tauon-test: DFLAGS+=--linker=$(WASMLD)
#taupn-test: DFLAGS+=/home/carsten/work/tagion/tools/wasi-druntime/wasi-sdk-21.0/share/wasi-sysroot/lib/wasm32-wasi/crt1.o
tauon-test: | $(DLIB)/.way 

env-tauon:
	$(PRECMD)
	$(call log.header, $@ :: env)
	$(call log.kvp, TAUON_ROOT, $(TAUON_ROOT))
	$(call log.kvp, TAUON_TEST_ROOT, $(TAUON_TEST_ROOT))
	$(call log.kvp, LIBEXT, $(LIBEXT))
	$(call log.kvp, WASI_SYSROOT, $(WASI_SYSROOT))
	$(call log.env, TAUON_TESTS, $(TAUON_TESTS))
	$(call log.env, TAUON_BINS, $(TAUON_BINS))
	$(call log.env, TAUON_DINC, $(TAUON_DINC))
	$(call log.env, TAUON_DFILES, $(TAUON_DFILES))
	$(call log.close)

.PHONY: env-tauon

env: env-tauon


tauon-run: tauon-test
	$(PRECMD)
	$(foreach wasm,$(TAUON_BINS), wasmer $(wasm);)

help-tauon:
	$(PRECMD)
	$(call log.header, $@ :: help)
	$(call log.help, make tauon-test, Compile the tauon tests as .wasm)
	$(call log.help, make clean-tauon, Cleans the tauon library)
	$(call log.close)


$(DBIN)/%.wasm: $(DSRC)/wasi/tests/%.d
	$(PRECMD)
	$(DC) $(DFLAGS) $(LIB) $(addprefix $(DVERSION)=,$(DVERSIONS)) $(addprefix -I,$(DINC)) $< $(OUTPUT)$@

#$(WASMLD) $(LIB) $(DOBJ)/$*.o $(WASI_LDFLAGS) -o $@

.PHONY: help-tauon

clean-tauon:
	$(PRECMD)
	$(call log.header, $@ :: clean)
	$(RM) $(LIBTVM)
	$(RMDIR) $(DOBJ)
	$(RMDIR) $(DBIN)
	
.PHONY: clean-tauon

proper-tauon:
	$(PRECMD)
	$(call log.header, $@ :: proper)
	$(RMDIR) $(DBUILD)

.PHONY: proper-tauon

clean: clean-tauon

proper: proper-tauon





