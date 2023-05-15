install-git-hooks:
	$(PRECMD)
	cp tub/scripts/pre-commit.sh .git/hooks/pre-commit

.PHONY: install-git-hooks
