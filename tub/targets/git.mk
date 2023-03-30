GIT_ORIGIN := "git@github.com:tagion"
GIT_SUBMODULES :=

install-git-hooks:
	$(PRECMD)
	cp tub/scripts/pre-commit.sh .git/hooks/pre-commit

.PHONY: install-git-hooks
