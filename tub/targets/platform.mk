
env-platform:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.kvp, GETARHC, $(GETARCH)}
	${call log.kvp, GETHOSTOS, $(GETHOSTOS)}
	${call log.kvp, GETOS, $(GETOS)}
	${call log.kvp, HOST, $(HOST)}
	${call log.kvp, PLATFORM, $(PLATFORM)}
	${call log.env, PLATFORMS, $(PLATFORMS)}
	${call log.env, CROSS_ENABLED, $(CROSS_ENABLED)}
	${call log.close}

env: env-platform

help-platform:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "Change target", "To change the target copy the options.mk to local.mk"}
	${call log.help, "", "And uncomment the target of choice in the local.mk"}
	${call log.help, "make all-platforms -k", "This will try to build all the target platforms"}
	${call log.help, "make platform", "This will build the selected target"}
	${call log.help, "make <PLATFORM>", "Or this would build the platform <PLATFORM>"}
	${call log.line}
	${call log.help, "make <PLATFORM>-<tag>", "Will execute the make <tag> for the <PLATFORM>"}
	${call log.line}
	${call log.help, "make proper-platform", "Will makes proper clean in the selected platform "}
	${call log.line}
	${call log.help, "make proper-<PLATFORM>", "Will execute the make proper-platform for the target <PLATFORM> "}
	${call log.line}
	${call log.help, "Platform setting", "The platform setting can be found in the platform.<NAME>.mk"}
	${call log.close}

help: help-platform

.PHONY: help-platform env-platform

all-platforms:
	${foreach platform,$(PLATFORMS), $(MAKE) PLATFORM=$(platform) platform -k;}

define platform.builder
${eval
$1:
	$(MAKE) PLATFORM=$1 platform

$1-%:
	$(MAKE) PLATFORM=$1 platform $$*

# prober-$1:
# 	$(MAKE) PLATFORM=$1 proper-platform

}
endef

${foreach platform,$(PLATFORMS), ${call platform.builder, $(platform)}}

proper-platform:
	$(PRECMD)
	$(RMDIR) $(DBUILD)
