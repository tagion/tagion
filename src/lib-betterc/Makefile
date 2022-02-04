REPOROOT?=${shell git rev-parse --show-toplevel}
<<<<<<< HEAD
BETTERCROOT=$(REPOROOT)/src/lib-betterc/
include $(BETTERCROOT)/git.mk
include $(BETTERCROOT)/setup.mk

BETTERCMK:=betterc.mk
ANDROIDMK:=android.mk
=======
include $(REPOROOT)/git.mk
include $(REPOROOT)/setup.mk

BETTERCMK:=betterc.mk
>>>>>>> 4f386fd9a5d04e3a5776a225aa91fba2a399caaa

run: $(TEST) hibon.valgrind
	$(TEST)

hibon.valgrind:
	valgrind $(TEST) | tee $@

$(TEST): dfiles.mk
	$(DC) $(TESTFLAGS) $(DFILES) $(UNITTEST) -of=$@

wasm:
	$(MAKE) -f $(BETTERCMK)

<<<<<<< HEAD
android:
	$(MAKE) -f $(ANDROIDMK) M64=yes
	$(MAKE) -f $(ANDROIDMK)
	$(MAKE) -f $(ANDROIDMK) M64=yes SHARED=1
	$(MAKE) -f $(ANDROIDMK) SHARED=1

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

=======
>>>>>>> 4f386fd9a5d04e3a5776a225aa91fba2a399caaa
include source.mk

clean: $(CLEANER)
	rm -f $(TEST)
	rm -f hibon.valgrind
<<<<<<< HEAD
	rm -fR $(BIN)
=======
>>>>>>> 4f386fd9a5d04e3a5776a225aa91fba2a399caaa
	$(MAKE) -f $(BETTERCMK) clean
