GIT_ORIGIN := "git@github.com:tagion"
GIT_SUBMODULES :=

install-git-hooks:
	$(PRECMD)
	cp tub/scripts/pre-commit.sh .git/hooks/

.PHONY: install-git-hooks
