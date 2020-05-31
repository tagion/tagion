REPOROOT?=${shell git rev-parse --show-toplevel}
include $(REPOROOT)/git.mk
include $(REPOROOT)/setup.mk

run: $(TEST)
	$(TEST)

$(TEST): dfiles.mk
	$(DC) $(TESTFLAGS) $(DFILES) $(UNITTEST) -of=$@

include source.mk

clean: $(CLEANER)
	rm -f $(TEST)
