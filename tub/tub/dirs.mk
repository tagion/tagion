DIR_BUILD := ${abspath ${DIR_ROOT}}/build/$(MTRIPLE)

# New simplified flow directories
DBIN := $(DIR_BUILD)/bin
DTMP := $(DIR_BUILD)/tmp
DSRC := ${abspath ${DIR_ROOT}}/src

MAKE_ENV += env-dirs
env-dirs:
	$(call log.header, env :: dirs)
	$(call log.kvp, DIR_ROOT, $(DIR_ROOT))
	$(call log.kvp, DIR_TUB, $(DIR_TUB))
	$(call log.kvp, DIR_BUILD, $(DIR_BUILD))
	$(call log.separator)
	$(call log.kvp, DBIN, $(DBIN))
	$(call log.kvp, DTMP, $(DTMP))
	$(call log.kvp, DSRC, $(DSRC))
	$(call log.close)