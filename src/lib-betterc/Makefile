REPOROOT?=${shell git rev-parse --show-toplevel}
BETTERCROOT=$(REPOROOT)/src/lib-betterc/
include $(BETTERCROOT)/git.mk
include $(BETTERCROOT)/setup.mk

BETTERCMK:=betterc.mk
ANDROIDMK:=android.mk

run: $(TEST) hibon.valgrind
	$(TEST)

hibon.valgrind:
	valgrind $(TEST) | tee $@

$(TEST): gen.dfiles.mk
	$(DC) $(TESTFLAGS) $(DFILES) $(UNITTEST) -of=$@

wasm:
	$(MAKE) -f $(BETTERCMK)

android:
	# $(MAKE) -f $(ANDROIDMK) M64=yes
	# $(MAKE) -f $(ANDROIDMK)
	$(MAKE) -f $(ANDROIDMK) M64=yes SHARED=1
	$(MAKE) -f $(ANDROIDMK) SHARED=1

android-obj:
	# $(MAKE) -f $(ANDROIDMK) M64=yes
	# $(MAKE) -f $(ANDROIDMK)
	$(MAKE) -f $(ANDROIDMK) M64=yes SHARED=1 obj
	$(MAKE) -f $(ANDROIDMK) SHARED=1 obj

android-test:
	# $(MAKE) -f $(ANDROIDMK) M64=yes all-test
	# $(MAKE) -f $(ANDROIDMK) all-test
	$(MAKE) -f $(ANDROIDMK) M64=yes SHARED=1 all-test
	$(MAKE) -f $(ANDROIDMK) SHARED=1 all-test

android-testc:
	# $(MAKE) -f $(ANDROIDMK) M64=yes all-testc
	# $(MAKE) -f $(ANDROIDMK) all-testc
	$(MAKE) -f $(ANDROIDMK) M64=yes SHARED=1 all-testc
	$(MAKE) -f $(ANDROIDMK) SHARED=1 all-testc


include source.mk

clean: $(CLEANER)
	rm -f $(TEST)
	rm -f hibon.valgrind
	rm -fR $(BIN)
	$(MAKE) -f $(BETTERCMK) clean
