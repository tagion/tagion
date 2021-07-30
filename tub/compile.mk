include $(DIR_TAGIL)/src/wraps/**/Makefile

define find_d_files
${shell find $(DIR_SRC)/${strip $1}/${strip $2} -name '*.d*'}
endef

define link_wrap
-L$(DIR_BUILD)/wraps -Llib${strip $1}.a
endef

# TODO: Add ldc-build-runtime for building phobos and druntime for platforms
# TODO: Add auto cloning wraps

ways: 
	$(PRECMD)mkdir -p $(DIR_BUILD)/wraps
	$(PRECMD)mkdir -p $(DIR_BUILD)/libs
	$(PRECMD)mkdir -p $(DIR_BUILD)/bins

bin/%: ctx/bin/% ways
	$(call log.close)

lib/%: ctx/lib/% ways
	$(call log.header, compiling lib/$(@F))

	# @echo todo - collect all libs and wraps before looking for D Files

	${eval LIBS += $(@F)}

	$(eval WRAPS := $(foreach X, $(WRAPS), $(eval WRAPS := $(filter-out $X, $(WRAPS)) $X))$(WRAPS))
	$(eval LIBS := $(foreach X, $(LIBS), $(eval LIBS := $(filter-out $X, $(LIBS)) $X))$(LIBS))

	$(call log.line, All dependencies of lib/$(@F) are present)
	$(call log.kvp, wraps, $(WRAPS))
	$(call log.kvp, libs, $(LIBS))
	${eval DFILES := ${foreach LIB, $(LIBS), ${call find_d_files, libs, $(LIB)}}}
	${eval DFILES += ${foreach WRAP, $(WRAPS), ${call find_d_files, wraps, $(WRAP)}}}
	${eval WRAP_LINKS := ${foreach WRAP, $(WRAPS), ${call link_wrap, $(WRAP)}}}
	${eval INCFLAGS += -I$(DIR_SRC)/wraps/p2p/d}
	${eval INCFLAGS += -I$(DIR_SRC)/wraps/p2p/d/p2p}
	${eval INCFLAGS += -I$(DIR_SRC)/wraps/p2p/d/p2p/cgo}
	
	$(call log.separator)
	# TODO: Move this to a macro (depend on env macro)
	${eval COMPILE_CMD := $(DC) $(DCFLAGS) $(INCFLAGS) $(DFILES) $(WRAP_LINKS) $(LDCFLAGS) -c -of$(DIR_BUILD)/libs/libtagion$(@F).a}
	$(call log.kvp, Compiler, $(DC))
	$(call log.kvp, DCFLAGS, $(DCFLAGS))
	$(call log.kvp, LDCFLAGS, $(LDCFLAGS))
	$(call log.kvp, INCFLAGS, $(INCFLAGS))
	$(call log.kvp, DIR_BUILD, $(DIR_BUILD)/$@)
	$(call log.kvp, D Files)
	$(call log.lines, $(DFILES))
	$(call log.kvp, Links)
	$(call log.lines, $(WRAP_LINKS))
	$(call log.separator)

	$(call log.line, Compiling...)
	$(call log.space)
	$(PRECMD)$(COMPILE_CMD)
	$(call log.close)