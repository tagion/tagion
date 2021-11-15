.PHONY: help
help:
	${eval TUB_COMMIT := ${shell cd $(DIR_TUB_ROOT)/tub; git rev-parse --short HEAD}}
	${eval TUB_BRANCH := ${shell cd $(DIR_TUB_ROOT)/tub; git rev-parse --abbrev-ref HEAD}}
	${call log.header, tub :: $(TUB_BRANCH) ($(TUB_COMMIT)) :: help }
	${call log.kvp, make help, Show this help}
	${call log.kvp, make env, Show current Make environment}
	${call log.separator}
	${call log.kvp, make clone-<specific>, Add source code of <speficic> module}
	${call log.kvp, make clone-all, Add all core modules}
	${call log.subheader, library compilation}
	${call log.kvp, make libtagion<specific>, Compile <specific> lib}
	${call log.kvp, make libtagion<specific> TEST=1, Run unit tests for <specific> lib}
	${call log.kvp, make libtagion<specific> DEPSREGEN=1, Regenerate dependency files (if you added/removed .d files)}
	${call log.subheader, executable compilation}
	${call log.kvp, make tagion<specific>, Compile <specific> bin}
	${call log.kvp, make tagion<specific> DEPSREGEN=1, Regenerate dependency files (if you added/removed .d files)}
	${call log.subheader, wrap compilation}
	${call log.kvp, make wrap-<specific>, Compile <specific> wrapper}
	${call log.separator}
	${call log.kvp, make clean, Clean built and generated files}
	${call log.kvp, make proper, Clean entire build directory, including wraps}
	${call log.close}
	${call log.line, Read more on GitHub: https://github.com/tagion/tub}
	${call log.close}
