DBUILD := ${abspath ${DROOT}}/build/$(MTRIPLE)

# New simplified flow directories
DBIN := $(DBUILD)/bin
DTMP := $(DBUILD)/tmp
DSRC := ${abspath ${DROOT}}/src

MAKE_ENV += env-dirs
env-dirs:
	$(call log.header, env :: dirs)
	$(call log.kvp, DBIN, $(DBIN))
	$(call log.kvp, DTMP, $(DTMP))
	$(call log.kvp, DSRC, $(DSRC))
	$(call log.close)