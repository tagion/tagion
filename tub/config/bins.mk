
#
# $1 : Program name
# $2 : Set name of the onetool
# $3 : Depends list
#
define DO_BIN
${eval
export _$1=$$(DBIN)/$1

export $${call DO_UPPER,$1}=$$(_$1)

BINS+=$$(_$1)

$1: target-$1
bins: $1

_TOOLS=$2

ifdef _TOOLS
info-$1:
	@echo _TOOLS defined $$(TAGION)

target-$1: target-$2
	@echo Tools enabled $1
	$(RM) $$(_$1)
	$(LN) $$(TAGION) $$(_$1)
else
info-$1:
	@echo _TOOLS undefined

target-$1: $$(DBIN)/$1


endif

env-$1:
	$$(PRECMD)
	$${call log.header, $$@ :: env}
	$${call log.kvp, $${call DO_UPPER,$1}, $$(_$1)}
	$${call log.env, LIBS_$1,$$(LIBS_$1)}
	$${call log.env, DFILES_$1,$$(DFILES_$1)}
	$${call log.close}

.PHONY: env-$1

env-bins: env-$1

clean-$1:
	$$(PRECMD)
	$${call log.header, $$@ :: clean}
	$$(RM) $$(DBIN)/$1

clean-bins: clean-$1

}
endef

env-bins:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.env, BINS, $(BINS)}
	${call log.close}

clean: clean-bins

.PHONY: clean-bins
