DBUILD := ${abspath ${DROOT}}/build/$(MTRIPLE)

# New simplified flow directories
DBIN := $(DBUILD)/bin
DTMP := $(DBUILD)/tmp

MAKE_ENV += env-dirs
env-dirs:
	$(PRECMD)
	$(call log.header, env :: dirs)
	$(call log.kvp, DBIN, $(DBIN))
	$(call log.kvp, DTMP, $(DTMP))
	$(call log.kvp, DSRC, $(DSRC))
	$(call log.kvp, DTUB, $(DTUB))
	$(call log.kvp, DROOT, $(DROOT))
	$(call log.close)