help:
	${eval TUB_VERSION := ${shell cd $(DIR_TUB_ROOT)/tub; git rev-parse --short HEAD}}
	${call log.header, tub version $(TUB_VERSION) :: help }
	${call log.kvp, make help, Show this help}
	${call log.kvp, make env, Show current Make environment}
	${call log.kvp, make update, Force update the tub itself}
	${call log.kvp, make install, Ensure correct local setup of the tub}
	${call log.separator}
	${call log.kvp, make add/<specific>, Add source code of <speficic> module}
	${call log.kvp, make add/public, Add all open-sourced modules}
	${call log.kvp, make add/core, Add all core modules}
	${call log.separator}
	${call log.kvp, make lib/<specific>, Compile <specific> lib}
	${call log.kvp, make bin/<specific>, Compile <specific> bin}
	${call log.kvp, make wrap-<specific>, Compile <specific> wrapper}
	${call log.separator}
	${call log.kvp, make libtest/<specific>, Compile and run <specific> lib test}
	${call log.separator}
	${call log.kvp, make clean, Clean build directory}
	${call log.close}
