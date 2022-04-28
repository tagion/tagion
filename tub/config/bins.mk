
# TAGIONWAVE?=$(DBIN)/tagionwave
# TAGIONBOOT?=$(DBIN)/tagionboot
# DARTUTIL?=$(DBIN)/dartutil
# HIBONUTIL?=$(DBIN)/hibonutil
# TAGIONWALLET?=$(DBIN)/wallet


define BIN
${eval
export $2?=$$(DBIN)/$1

BINS+=$$($2)

$1: target-$1
bins: $1

LIBS_$1+=$3
#DFILES_$1+=xxx
DFILES_$1+=$${shell find $$(DSRC) -name "*.d" -a -path "*/src/bin-tagionwave/*" -a -not -path "*/unitdata/*"}
target-$1: LIBS+=$$(LIBS_$1)
#target-$1: DFILES+=$$(DFILES_$1)

# tar-$1: DFILES+=$${shell find $$(DSRC) -name "*.d" -a -path "*/src/bin-$1/*" -a -not -path "*/unitdata/*"}
target-$1: $$(DBIN)/$1

env-$1:
	$$(PRECMD)
	$${call log.header, $$@ :: env}
	$${call log.kvp, $2, $$($2)}
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
