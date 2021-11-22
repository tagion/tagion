CLANG := ${shell which clang}

tools: $(MAKETOOLS)
	@

MAKE_ENV += env-tools
env-tools:
	$(call log.header, env :: tools)
	$(call log.kvp, CLANG, $(CLANG))
	$(call log.close)