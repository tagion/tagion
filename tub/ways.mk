%/.way:
	$(PRECMD)$(MKDIR) $(@D)
	$(PRECMD)$(TOUCH) $@

$(DBIN):
	$(PRECMD)$(MKDIR) $@
