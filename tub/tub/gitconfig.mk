BLANK :=
define NEWLINE

$(BLANK)
endef

.ONESHELL:

GITS:=$(DMAKEFILE)/tub/gits.d
gitconfig:
	@cd $(DMAKEFILE);
	@echo $(DMAKEFILE)/tub/gits.d config --local alias.all "!$(GITS)"
