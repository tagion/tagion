MODE0:=$(TESTBENCH)/mode0
MODE0_DATA:=$(MODE0)/data
MODE0_DART:=$(MODE0_DATA)/node0/dart.drt
MODE0_LOG:=$(MODE0)/mode0_script.log
MODE0_FLAGS:=-N 7 -t 200
MODE0_FLAGS+=--pid=$(MODE0)/tagioinwave.pid

mode0: $(MODE0)/.way
mode0: tagionwave $(MODE0_DART)
	cd $(MODE0)
	script -c "$(TAGIONWAVE) $(MODE0_FLAGS)" $(MODE0_LOG)

.PHONY: mode0
testbench: mode0

$(MODE0_DART): | dart
$(MODE0_DART): $(DARTDB)
	$(PRECMD)
	$(MKDIR) $(@D)
	$(CP) $< $@


env-mode0:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.kvp, MODE0,$(MODE0)}
	${call log.kvp, MODE0_DATA,$(MODE0_DATA)}
	${call log.kvp, MODE0_DART,$(MODE0_DART)}
	${call log.kvp, MODE0_LOG,$(MODE0_LOG)}
	${call log.kvp, MODE0_FLAGS,"$(MODE0_FLAGS)"}
	${call log.close}

.PHONY: env-mode0
env-testbench: env-mode0

#run: mode0

clean-mode0:
	$(PRECMD)
	${call log.header, $@ :: clean}
	$(RMDIR) $(MODE0)
	${call log.close}

.PHONY: clean-mode0

clean-testbench: clean-mode0
