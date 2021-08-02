include $(DIR_TAGIL)/src/wraps/**/Makefile

define find_d_files
${shell find $(DIR_SRC)/${strip $1}/${strip $2} -name '*.d*'}
endef

define link_wrap
$(LINKERFLAG)$(DIR_BUILD)/wraps/lib${strip $1}.a
endef

define compile_cmd
$(DC) $(DCFLAGS) $(INCFLAGS) $(DFILES) $(WRAP_LINKS) $(LDCFLAGS) -c -of$(DIR_BUILD)/libs/libtagion$(@F).a
endef

define test_cmd
$(DC) $(DCFLAGS) $(INCFLAGS) $(DFILES) $(WRAP_LINKS) $(LDCFLAGS) $(DEBUG) -o- -unittest -g -main
endef

# TODO: Add ldc-build-runtime for building phobos and druntime for platforms
# TODO: Add auto cloning wraps
# TODO: Add revision
# TODO: Add unit tests

ways: 
	$(PRECMD)mkdir -p $(DIR_BUILD)/wraps
	$(PRECMD)mkdir -p $(DIR_BUILD)/libs
	$(PRECMD)mkdir -p $(DIR_BUILD)/bins

bin/%: ctx/bin/% ways
	$(call log.close)

lib/%: ctx/lib/% ways
	$(call log.header, compiling lib/$(@F))

	${eval LIBS += $(@F)}

	$(eval WRAPS := $(foreach X, $(WRAPS), $(eval WRAPS := $(filter-out $X, $(WRAPS)) $X))$(WRAPS))
	$(eval LIBS := $(foreach X, $(LIBS), $(eval LIBS := $(filter-out $X, $(LIBS)) $X))$(LIBS))

	$(call log.line, All dependencies of lib/$(@F) are present)
	$(call log.space)
	$(call log.kvp, OS, $(OS))
	$(call log.kvp, Architecture, $(ARCH))
	$(call log.separator)
	$(call log.kvp, wraps, $(WRAPS))
	$(call log.kvp, libs, $(LIBS))
	${eval DFILES := ${foreach LIB, $(LIBS), ${call find_d_files, libs, $(LIB)}}}
	${eval DFILES += ${foreach WRAP, $(WRAPS), ${call find_d_files, wraps, $(WRAP)}}}
	
	$(call log.separator)
	$(call log.kvp, Compiler, $(DC))
	$(call log.kvp, DCFLAGS, $(DCFLAGS))
	$(call log.kvp, LDCFLAGS, $(LDCFLAGS))

	$(call log.separator)
	$(call log.kvp, D Files)
	$(call log.lines, $(DFILES))

	$(call log.separator)
	$(call log.kvp, Includes)
	$(call log.lines, $(INCFLAGS))

	$(call log.separator)
	$(call log.kvp, Linkings)
	$(call log.lines, $(WRAP_LINKS))

	$(call log.separator)
	$(call log.line, Compiling...)
	$(call log.space)
	$(PRECMD)$(compile_cmd)
	$(call log.kvp, Compiled, $(DIR_BUILD)/$(@D)s/libtagion$(@F).a)
	$(call log.close)

test/lib/%: ctx/lib/%
	$(call log.header, testing lib/$(@F))

	${eval LIBS += $(@F)}

	$(eval WRAPS := $(foreach X, $(WRAPS), $(eval WRAPS := $(filter-out $X, $(WRAPS)) $X))$(WRAPS))
	$(eval LIBS := $(foreach X, $(LIBS), $(eval LIBS := $(filter-out $X, $(LIBS)) $X))$(LIBS))

	$(call log.kvp, OS, $(OS))
	$(call log.kvp, Architecture, $(ARCH))
	$(call log.separator)
	$(call log.kvp, wraps, $(WRAPS))
	$(call log.kvp, libs, $(LIBS))

	${eval DFILES := ${foreach LIB, $(LIBS), ${call find_d_files, libs, $(LIB)}}}
	${eval DFILES += ${foreach WRAP, $(WRAPS), ${call find_d_files, wraps, $(WRAP)}}}
	${eval WRAP_LINKS += ${foreach WRAP, $(WRAPS), ${call link_wrap, $(WRAP)}}}

	$(call log.separator)
	$(call log.kvp, Compiler, $(DC))
	$(call log.kvp, DCFLAGS, $(DCFLAGS))
	$(call log.kvp, LDCFLAGS, $(LDCFLAGS))

	$(call log.separator)
	$(call log.kvp, D Files)
	$(call log.lines, $(DFILES))

	$(call log.separator)
	$(call log.kvp, Includes)
	$(call log.lines, $(INCFLAGS))

	$(call log.separator)
	$(call log.kvp, Linkings)
	$(call log.lines, $(WRAP_LINKS))

	$(call log.separator)
	$(call log.line, Testing...)
	$(call log.space)
	$(PRECMD)$(test_cmd)

.PHONY: test/lib/%