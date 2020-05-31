REPOROOT?=${shell git rev-parse --show-toplevel}
include $(REPOROOT)/git.mk
include $(REPOROOT)/setup.mk

test: dfiles.mk
	$(DC) $(TESTFLAGS) $(DFILES) $(UNITTEST) -of=unittest

include source.mk

clean: $(CLEANER)
