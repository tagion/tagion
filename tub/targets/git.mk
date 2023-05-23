install-git-hooks:
	$(PRECMD)
	cp -r git/hooks .git/hooks

.PHONY: install-git-hooks
