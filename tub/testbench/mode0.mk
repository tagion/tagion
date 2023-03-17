MODE0_ROOT:=$(TESTLOG)/mode0
MODE0_DATA:=$(MODE0_ROOT)/data
MODE0_DART:=$(MODE0_DATA)/node0/dart.drt
MODE0_LOG:=$(MODE0_ROOT)/mode0_script.log
MODE0_FLAGS:=-N 7 -t 200
MODE0_FLAGS+=--monitor --monitor-port 10920
MODE0_FLAGS+=--pid=$(MODE0_ROOT)/tagionwave.pid
MODE0_FLAGS+=--dart-init=false
MODE0_FLAGS+=--logger-size=2000
# MODE0_FLAGS+=--epochs=$(EPOCHS);

mode0: mode0-dart
mode0: $(MODE0_DATA)/.way
mode0: DARTDB=$(MODE0_DART)
mode0: dart
mode0: tagionwave
ifdef DDD
mode0:
	${call header, $@ :: mode0 start with ddd}
	cd $(MODE0_ROOT)
	echo echo tagionwave\\\\n > .gdbinit
	#echo "process handle --stop false --notify false SIGUSR1 SIGUSR2" >> .gdbinit
	echo "handle SIGUSR1 nostop" >> .gdbinit
	echo "handle SIGUSR2 nostop" >> .gdbinit
	echo echo args is set to tagionwave\\\\n >> .gdbinit
	echo set args tagionwave $(MODE0_FLAGS) >> .gdbinit
	echo show args >> .gdbinit
	ddd $(TAGIONWAVE)
else
mode0:
	cd $(MODE0_ROOT)
	echo MODE0_FLAGS=$(MODE0_FLAGS) >/tmp/mode0_flags.txt
	script -c "$(TAGIONWAVE) $(MODE0_FLAGS)" $(MODE0_LOG)
endif

.PHONY: mode0
testnet: mode0

mode0-dart: DARTDB=$(MODE0_DART)
mode0-dart: dart

#$(MODE0_DART): dart

# $(MODE0_DART): $(DARTDB)
# 	$(PRECMD)
# 	$(MKDIR) $(@D)
# 	$(CP) $< $@


env-mode0:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.kvp, MODE0_ROOT,$(MODE0_ROOT)}
	${call log.kvp, MODE0_DATA,$(MODE0_DATA)}
	${call log.kvp, MODE0_DART,$(MODE0_DART)}
	${call log.kvp, MODE0_LOG,$(MODE0_LOG)}
	${call log.kvp, MODE0_FLAGS,"$(MODE0_FLAGS)"}
	${call log.close}

.PHONY: env-mode0
env-testnet: env-mode0

help-mode0:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make mode0", "Will start the test network in mode0"}
	${call log.help, "make mode0 DDD=1", "Will start mode0 in ddd"}
	${call log.help, "make mode0-ddd", "Does the same as make mode0 DDD=1"}
	${call log.help, "", "IMPORTANT: To enable ddd you need to add"}
	${call log.help, "", "           set auto-load safe-path /"}
	${call log.help, "", "           to the ~/.gdbinit file"}
	${call log.help, "make mode0-dart", "Create the DART for mode0"}
	${call log.help, "make clean-mode0", "Will clean all data in mode 0"}
	${call log.help, "make env-mode0", "Lists the setting for mode 0"}
	${call log.close}

.PHONY: help-mode0

help: help-mode0

clean-mode0:
	$(PRECMD)
	${call log.header, $@ :: clean}
	$(RMDIR) $(MODE0_ROOT)
	${call log.close}

.PHONY: clean-mode0

clean-testnet: clean-mode0

check-mode0:
	$(PRECMD)
	${call log.header, $@ :: check}
	echo "Bullseye mode0"
	@${foreach node_no,0 1 2 3 4 5 6, $(DBIN)/dartutil --eye -d$(MODE0_DATA)/node$(node_no)/dart.drt;}
	${call log.close}

check: check-mode0
