
env-platform:
	$(PRECMD)
	${call log.header, $@ :: platform}
	${call log.kvp, PLATFORM, $(PLATFORM)}
	${call log.close}

env: env-platform

help-platform:
	$(PRECMD)
	${call log.header, $@ :: platform}
	${call log.help, "Change target", "To change the target copy the options.mk to local.mk"}
	${call log.help, "", "And uncomment the target of choice in the local.mk"}
	${call log.help, "make all-platform -k", "This will try to build all the target platforms"}
	${call log.help, "make target", "This will build the selected target"}
	${call log.help, "Platform setting", "The platform setting can be found in the platform.<NAME>.mk"}

	${call log.close}

help: help-platform

.PHONY: help-platform env-platform

all-platform:
	${foreach platform,$(PLATFORMS), $(MAKE) PLATFORM=$(platform) target -k;}
