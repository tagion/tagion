BLANK :=
define NEWLINE

$(BLANK)
endef

.ONESHELL:

GITS:=$(DMAKEFILE)/tub/gits.d
gitconfig:
	@cd $(DMAKEFILE);
	$(GITS) config --local alias.all "!$(GITS)"
	git all --config
