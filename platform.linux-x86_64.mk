
#
# Linux x86_64
#
LINUX_X86_64:=linux-x86_64

PLATFORMS+=$(LINUX_X86_64)

ifeq ($(PLATFORM),$(LINUX_X86_64))

DINC+=${shell find $(DSRC) -maxdepth 1 -type d -path "*src/lib-*" }
#DINC+=${shell find $(DSRC) -type d -path "*/p2p" }

${call DDEPS,$(DBUILD),$(DFILES)}

endif

$(LINUX_X86_64)-%:
	$(MAKE) PLATFORM=$(LINUX_X86_64) $@

$(LINUX_X86_64):
	$(MAKE) PLATFORM=$(LINUX_X86_64)
