
#
# $1 : Program name
# $2 : Depends list
#
define DO_BIN
${eval
export _$1=$$(DBIN)/$1

export $${call DO_UPPER,$1}=$$(_$1)

BINS+=$$(_$1)

bins: $1

$1: target-$1

$$(DBIN)/$1: $2

target-$1: $$(DBIN)/$1

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
