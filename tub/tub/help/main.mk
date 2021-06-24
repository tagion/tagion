HELP+=help-main
help-main:
	$(call log.open, help :: general)
	$(call log.kvp, make help, Show this help)
	$(call log.separator)
	$(call log.kvp, make info, Show general information about this repository and compile settings)
	$(call log.separator)
	$(call log.kvp, make all, Build everything for the host platform)
	$(call log.kvp, make lib, Build libraries for the host platform)
	$(call log.separator)
	$(call log.kvp, make clean, Build libraries for the host platform)
	$(call log.kvp, make proper, Build libraries for the host platform)
	$(call log.close)
