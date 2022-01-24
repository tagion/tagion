
ifndef DOBJALL
PREBUILD:=prebuild
endif

prebuild:
	$(MAKE) $(GEN_DDEPS_MK)

.PHONY: prebuild
