MODE1_ROOT:=$(TESTBENCH)/mode1
MODE1_DART:=$(MODE1_ROOT)/dart.drt
MODE1_CONFIG:=$(MODE1_ROOT)/tagionwave.json
MODE1_SRC_CONFIG:=$(FUND)/mode1/tagionwave.json
MODE1_LOG:=$(MODE1_ROOT)/mode1_script.log
#MODE1_FLAGS:=-N 7 -t 200

define MODE1
${eval

DART_$1=$$(MODE1_ROOT)/dart-$1.drt

$1-mode1: $$(MODE1_ROOT)/.way
$1-mode1: $$(DART_$1)

mode1: $1-mode1

clean-mode1-$1:
	$$(PRECMD)
	$${call log.header, $$@ :: clean}
	$$(RM) $$(DART_$1)
	$${call log.close}

$$(DART_$1): $$(MODE1_CONFIG)
	$$(PRECMD)
	echo $$(TAGIONWAVE) $$(MODE1_CONFIG) $$(MODE1_FALGS) --port $$(HOSTPORT) -p $$(TRANSACTIONPORT) -P $$(MONITORPORT) --dart-filenamme=$$@ --dart-syncronize=$$(DARTSYNC) --pid $$(MODE1_ROOT)/tagionwave_$1.pid

}
endef

mode1: $(MODE1_ROOT)/.way
mode1: tagionwave $(MODE1_DART) $(MODE1_CONFIG)
	cd $(MODE1_ROOT)
	script -c "$(TAGIONWAVE) $(MODE1_FLAGS)" $(MODE1_LOG)

.PHONY: mode1
testbench: mode1

$(MODE1_DART): | dart
$(MODE1_DART): $(DARTDB)
	$(PRECMD)
	$(MKDIR) $(@D)
	$(CP) $< $@

$(MODE1_CONFIG): $(MODE1_SRC_CONFIG)
	$(PRECMD)
	$(CP) $< $@

env-mode1:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.kvp, MODE1_ROOT,$(MODE1_ROOT)}
	${call log.kvp, MODE1_DART,$(MODE1_DART)}
	${call log.kvp, MODE1_LOG,$(MODE1_LOG)}
	${call log.kvp, MODE1_FLAGS,"$(MODE1_FLAGS)"}
	${call log.close}

.PHONY: env-mode1
env-testbench: env-mode1

run: mode1

clean-mode1:
	$(PRECMD)
	${call log.header, $@ :: clean}
	$(RMDIR) $(MODE1)
	${call log.close}

.PHONY: clean-mode1

clean-testbench: clean-mode1

${foreach mode1,$(MODE1_LIST),${call MODE1,$(mode1)}}
