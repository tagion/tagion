
#
# Linux x86_64
#
LINUX_X86_64:=x86_64-linux

PLATFORMS+=$(LINUX_X86_64)
ifeq ($(PLATFORM),$(LINUX_X86_64))

DINC+=${shell find $(DSRC) -maxdepth 1 -type d -path "*src/lib-*" }
ifdef BETTERC
DFILES?=${shell find $(DSRC) -type f -name "*.d" -path "*src/lib-betterc*" -a -not -path "*/tests/*"}
else
DFILES?=${shell find $(DSRC) -type f -name "*.d" -path "*src/lib-*" -a -not -path "*/tests/*"}
endif


traget-linux: | $(DBUILD)/.way
#target-linux: | secp256k1 openssl p2pgowrapper
target-linux: | secp256k1 p2pgowrapper
target-linux: dstep
target-linux: $(DBUILD)/gen.ddeps.mk
#traget-linux: $(DBUILD)/gen.dfiles.mk

target-linux:
	@echo DBUILD $(DBUILD)

.PHONY: traget-linux

test-linux:
	@echo $(DBUILD)
	@echo $(GEN_DFILES_MK)
	@echo $(DFILES)
#${call DDEPS,$(DBUILD),$(DFILES)}

# test44:
# 	@echo $(PLATFORM)

endif

# $(LINUX_X86_64)-%:
# 	$(MAKE) PLATFORM=$(LINUX_X86_64) $@

# $(LINUX_X86_64):
# 	$(MAKE) PLATFORM=$(LINUX_X86_64)
