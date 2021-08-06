meta/%:
	${call log.header}
	$(PRECMD)$(CP) $(DIR_TAGIL)/metas/$(@F).meta $(DIR_TAGIL_ROOT)/.meta
	${call log.line, Initialized $(@F) .meta file at $(DIR_TAGIL_ROOT)/.meta}
	${call log.close}