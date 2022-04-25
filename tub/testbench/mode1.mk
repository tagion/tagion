MODE1_ROOT:=$(TESTBENCH)/mode1
MODE1_DART:=$(MODE1_ROOT)/dart.drt
MODE1_CONFIG:=$(MODE1_ROOT)/tagionwave.json
MODE1_SRC_CONFIG:=$(FUND)/mode1/tagionwave.json
MODE1_LOG:=$(MODE1_ROOT)/mode1_script.log
MODE1_FLAGS:=-N 7 -t 200

define MODE1
${eval

DART_$1=$$(MODE1)/dart-$1.drt

$1-mode1: $$(MODE1)/dart-$1.drt

mode1: $1-mode1

clean-mode1-$1:
	$$(PRECMD)
	$${call log.header, $$@ :: clean}
	$$(RM) $$(DART_$1)
	$${call log.close}

$$(DART_$1):
	$$(PRECMD)
	echo $$(TAGIONWAVE) --port $$(HOSTPORT) -p $$(TRANSACTPORT) -P $$(MONITORPORT) --dart-filenamme=$$@ --dart-syncronize=$(DARTSYNC)


}
endef

mode1: $(MODE1)/.way
mode1: tagionwave $(MODE1_DART) $(MODE1_CONFIG)
	cd $(MODE1)
	script -c "$(TAGIONWAVE) $(MODE1_FLAGS)" $(MODE1_LOG)

.PHONY: mode1
testbench: mode1

$(MODE1_DART): | dart
$(MODE1_DART): $(DARTDB)
	$(PRECMD)
	$(MKDIR) $(@D)
	$(CP) $< $@

$(MODE1_CONFIG): $(MODE1_CONFIG)
	$(PRECMD)
	$(CP) $< $@


env-mode1:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.kvp, MODE1,$(MODE1)}
	${call log.kvp, MODE1_DATA,$(MODE1_DATA)}
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
