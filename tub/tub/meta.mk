meta/%:
	${call log.header}
	$(PRECMD)$(CP) $(DIR_TUB)/metas/$(@F).meta $(DIR_TUB_ROOT)/.meta
	${call log.line, Initialized $(@F) .meta file at $(DIR_TUB_ROOT)/.meta}
	${call log.close}