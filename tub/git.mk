checkout-%:
	$(PRECMD)$(REX) git checkout $*
	$(PRECMD)echo "BRANCH := $*" > $(DROOT)/local.branch.mk

branch-%:
	${eval _BRANCH_SUFFIX := ${shell sh $(DTUB)/random.sh}}
	$(PRECMD)$(REX) git checkout -b $*.$(_BRANCH_SUFFIX)
	$(PRECMD)echo "BRANCH := $*.$(_BRANCH_SUFFIX)" > $(DROOT)/local.branch.mk