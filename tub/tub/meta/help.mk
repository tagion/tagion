.PHONY: help
help:
	${eval TUB_VERSION := ${shell cd $(DIR_TUB_ROOT)/tub; git rev-parse --short HEAD}}
	${call log.header, tub (version $(TUB_VERSION)) :: help }
	${call log.kvp, make help, Show this help}
	${call log.kvp, make env, Show current Make environment}
	${call log.kvp, make update, Force update the tub itself}
	${call log.kvp, make checkout/<branch-or-commit>, Switch tub to specific branch or commit}
	${call log.kvp, make run, Create recursive 'run' script}
	${call log.kvp, make derun, Remove recursive 'run' script}
	${call log.separator}
	${call log.kvp, make add-<specific>, Add source code of <speficic> module}
	${call log.kvp, make add-core, Add all core modules}
	${call log.separator}
	${call log.kvp, make libtagion<specific>, Compile <specific> lib}
	${call log.kvp, make tagion<specific>, Compile <specific> bin}
	${call log.kvp, make wrap-<specific>, Compile <specific> wrapper}
	${call log.separator}
	${call log.kvp, make runtest_libtagion<specific>, Compile and run <specific> lib test}
	${call log.separator}
	${call log.kvp, make clean, Clean build directory}
	${call log.kvp, make clean-all, Clean build directory}
	${call log.close}
	${call log.line, Read more on GitHub: https://github.com/tagion/tub}
	${call log.close}
