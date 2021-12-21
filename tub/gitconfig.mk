GITS:=$(DTUB)/gits.d
gitconfig:
	$(GITS) config --local alias.all "!$(GITS)"
	git all --config
