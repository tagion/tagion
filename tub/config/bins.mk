
#
# $1 : Program name
# $2 : List of libraries used by the program
# $3 : Set if the program is tagion tool
#
define DO_BIN
${eval
ENV_BIN_$1=$$(DBIN)/$1
#export ENV_BIN_$1?=$$(DBIN)/$1

BINS+=$$(ENV_BIN_$1)

$1: target-$1
bins: $1

_TOOLS=$3

ifdef _TOOLS
info-$1:
	@echo _TOOLS defined $$(TAGION)

target-$1: target-tagion
	@echo Tools enabled $1
	rm -f $$(ENV_BIN_$1)
	ln -s $$(TAGION) $$(ENV_BIN_$1)
else
info-$1:
	@echo _TOOLS undefined
LIBS_$1+=$2

target-$1: LIBS+=$$(LIBS_$1)

target-$1: $$(DBIN)/$1
endif

env-$1:
	$$(PRECMD)
	$${call log.header, $$@ :: env}
	$${call log.kvp, ENV_BIN_$1, $$(ENV_BIN_$1)}
	$${call log.env, LIBS_$1,$$(LIBS_$1)}
	$${call log.env, DFILES_$1,$$(DFILES_$1)}
	$${call log.close}

.PHONY: env-$1

env-bins: env-$1
# tar-$1:
# 	@echo $$(DFILES)
# 	@echo $$(LIBS)

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
