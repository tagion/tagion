DIR_BUILD := ${abspath ${DROOT}}/build/$(MTRIPLE)

# New simplified flow directories
DBIN := $(DIR_BUILD)/bin
DTMP := $(DIR_BUILD)/tmp
DSRC := ${abspath ${DROOT}}/src

MAKE_ENV += env-dirs
env-dirs:
	$(call log.header, env :: dirs)
	$(call log.kvp, DROOT, $(DROOT))
	$(call log.kvp, DTUB, $(DTUB))
	$(call log.kvp, DIR_BUILD, $(DIR_BUILD))
	$(call log.separator)
	$(call log.kvp, DBIN, $(DBIN))
	$(call log.kvp, DTMP, $(DTMP))
	$(call log.kvp, DSRC, $(DSRC))
	$(call log.close)