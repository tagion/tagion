


PATCH_FILES=${shell git ldiff $1 | grep -v -E "bdd/*" | grep -v -E "regression/*"| grep -v -E "lib-behaviour"| grep -v -E "docs/*"}

env-patch-%:
	$(PRECMD)
	${call log.env, PATCH_FILES, ${call PATCH_FILES,$*}}

patch: patch-$(BRANCH)

patch-%:
	$(PRECMD)
	git checkout --patch $* ${call PATCH_FILES,$*}

help-patch:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make patch-<branch>", "Creates list of patch files from <branch>"}
	${call log.help, "make clean-patch-<branch>", "Clean the patch files from the <branch>"}
	${call log.close}

.PHONY: help-patch

clean-pacth: clean-patch-$(BRANCH)

clean-patch-%:
	$(PRECMD)
	$(RM) ${call PATCH_FILES,$*}

