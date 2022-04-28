export MODE1_ROOT:=$(TESTBENCH)/mode1
#export MODE1_DART:=$(MODE1_ROOT)/dart.drt
#export MODE1_CONFIG:=$(MODE1_ROOT)/tagionwave.json
#export MODE1_SRC_CONFIG:=$(FUND)/mode1/tagionwave.json
#export MODE1_LOG:=$(MODE1_ROOT)/mode1_script.log
MODE1_FLAGS:=-N 7 -t 300
MODE1_FLAGS+=--net-mode=local
MODE1_FLAGS+=--boot=$(MODE1_ROOT)/boot.hibon


define MODE1
${eval

MODE1_CONFIG_$1=$$(MODE1_ROOT)/tagionwave-$1.json
MODE1_DARTFILE_$1=$$(MODE1_ROOT)/dart-$1.drt
MODE1_PID_$1=$$(MODE1_ROOT)/tagionwave_$1.pid
MODE1_LOG_$1=$$(MODE1_ROOT)/tagionwave_$1.log

mode1-run-$1: export TAGIONCONFIG=$$(MODE1_CONFIG_$1)
mode1-run-$1: export TAGIONLOG=$$(MODE1_LOG_$1)

mode1-$1: DARTFILE=$$(MODE1_DART_$1)
mode1-$1: target-tagionwave
mode1-$1: $$(MODE1_ROOT)/.way
#mode1-$1: $$(MODE1_CONFIG)
mode1-$1: $$(MODE1_DART)

clean-mode1-$1:
	$$(PRECMD)
	$${call log.header, $$@ :: clean}
	$$(RM) $$(DART_$1)
	$${call log.close}

mode1-run-$1: mode1-$1
	$$(PRECMD)
	gnome-terminal --working-directory=$$(MODE1_ROOT) --tab -- $$(SCRIPTS)/tagionrun.sh

.PHONY: mode1-run-$1
mode1: mode1-run-$1

mode1-$1: $$(MODE1_CONFIG_$1)

$$(MODE1_CONFIG_$1): $$(MODE1_ROOT)/.way
$$(MODE1_CONFIG_$1): target-tagionwave
$$(MODE1_CONFIG_$1):
	$$(PRECMD)
	$$(TAGIONWAVE) $$@ $$(MODE1_FLAGS) --port $$(HOSTPORT) -p $$(TRANSACTIONPORT) -P $$(MONITORPORT) --dart-filename=$$(MODE1_DARTFILE_$1) --dart-synchronize=$$(DARTSYNC) --pid=$$(MODE1_PID_$1) -O

env-mode1-$1:
	$$(PRECMD)
	$${call log.header, $$@ :: env}
	$${call log.kvp, MODE1_CONFIG_$1,$$(MODE1_CONFIG_$1)}
	$${call log.kvp, MODE1_DARTFILE_$1,$$(MODE1_DARTFILE_$1)}
	$${call log.kvp, MODE1_PID_$1,$$(MODE1_PID_$1)}
	$${call log.close}

.PHONY: env-mode1
env-mode1: env-mode1-$1

}
endef

mode1: $(MODE1_ROOT)/.way
mode1: tagionwave $(MODE1_DART)

.PHONY: mode1
testbench: mode1

# $(MODE1_DART): | dart
# $(MODE1_DART): $(DARTDB)
# 	$(PRECMD)
# 	$(MKDIR) $(@D)
# 	$(CP) $< $@

# $(MODE1_CONFIG): $$(MODE1_ROOT)/.way
# $(MODE1_CONFIG): $(MODE1_SRC_CONFIG)
# 	$(PRECMD)
# 	cp $< $@

help-mode1:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make mode1", "Will start the test network in mode1"}
	${call log.help, "make mode1-stop", "Stops all nodes"}
	${call log.help, "make clean-mode1", "Will clean all data in mode 1"}
	${call log.help, "make mode1-run-<n>", "Will start node <n> in the [$(MODE1_LIST)]"}
	${call log.help, "make mode1-<n>", "Creates the network config file for node <n> in the [$(MODE1_LIST)]"}
	${call log.close}

help: help-mode1
.PHONY: help-mode1

env-mode1:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.kvp, MODE1_FLAGS,"$(MODE1_FLAGS)"}
	${call log.env, MODE1_LIST,$(MODE1_LIST)}
	${call log.close}

.PHONY: env-mode1
env-testbench: env-mode1

#run: mode1

clean-mode1:
	$(PRECMD)
	${call log.header, $@ :: clean}
	$(RMDIR) $(MODE1_ROOT)
	${call log.close}

.PHONY: clean-mode1

clean-testbench: clean-mode1

${foreach mode1,$(MODE1_LIST),${call MODE1,$(mode1)}}
