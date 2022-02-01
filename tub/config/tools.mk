CLANG := ${shell which clang}

tools: $(MAKETOOLS)
	@

MAKE_ENV += env-tools
env-tools:
	$(PRECMD)
	$(call log.header, env :: tools)
	$(call log.kvp, CLANG, $(CLANG))
	$(call log.close)