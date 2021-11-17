checkout-%:
	$(PRECMD)$(REX) git checkout $*
	$(PRECMD)echo "BRANCH := $*" > $(DIR_ROOT)/local.branch.mk

branch-%:
	${eval _BRANCH_SUFFIX := ${shell sh $(DIR_TUB)/random.sh}}
	$(PRECMD)$(REX) git checkout -b $*.$(_BRANCH_SUFFIX)
	$(PRECMD)echo "BRANCH := $*.$(_BRANCH_SUFFIX)" > $(DIR_ROOT)/local.branch.mk