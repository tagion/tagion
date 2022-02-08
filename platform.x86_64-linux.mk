
#
# Linux x86_64
#
LINUX_X86_64:=linux-x86_64

PLATFORMS+=$(LINUX_X86_64)
ifeq ($(PLATFORM),$(LINUX_X86_64))

DINC+=${shell find $(DSRC) -maxdepth 1 -type d -path "*src/lib-*" }
ifdef BETTERC
DFILES?=${shell find $(DSRC) -type f -name "*.d" -path "*src/lib-betterc*" -a -not -path "*/tests/*"}
else
DFILES?=${shell find $(DSRC) -type f -name "*.d" -path "*src/lib-*" -a -not -path "*/tests/*"}
endif

${call DDEPS,$(DBUILD),$(DFILES)}

test44:
	@echo $(PLATFORM)

endif

# $(LINUX_X86_64)-%:
# 	$(MAKE) PLATFORM=$(LINUX_X86_64) $@

# $(LINUX_X86_64):
# 	$(MAKE) PLATFORM=$(LINUX_X86_64)
