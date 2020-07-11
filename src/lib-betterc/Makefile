REPOROOT?=${shell git rev-parse --show-toplevel}
include $(REPOROOT)/git.mk
include $(REPOROOT)/setup.mk

BETTERCMK:=betterc.mk

run: $(TEST) hibon.valgrind
	$(TEST)

hibon.valgrind:
	valgrind $(TEST) | tee $@

$(TEST): dfiles.mk
	$(DC) $(TESTFLAGS) $(DFILES) $(UNITTEST) -of=$@

wasm:
	$(MAKE) -f $(BETTERCMK)

include source.mk

clean: $(CLEANER)
	rm -f $(TEST)
	rm -f hibon.valgrind
	$(MAKE) -f $(BETTERCMK) clean
