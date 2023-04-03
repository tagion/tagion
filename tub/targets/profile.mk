
env-profile:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.env, DPROFILE, $(DPROFILE)}
	${call log.close}

.PHONY: env-profile
env: env-profile

help-profile:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make PROFILE=1 <target>", "Set PROFILE to enable profiling"}
	${call log.close}

.PHONY: help-profile
help: help-profile


