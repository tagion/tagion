
#
# Linux x86_64
#
LINUX_X86_64:=linux-x86_64

PLATFORMS+=$(LINUX_X86_64)

ifeq ($(PLATFORM),$(LINUX_X86_64))

DINC+=${shell find $(DSRC) -maxdepth 1 -type d -path "*src/lib-*"}

test37:
	@echo $@ $(DIFILES)
	@echo $@ $(DIFILES.p2p.cgo)
	@echo HFILES.p2p.cgo $(HFILES.p2p.cgo)
	@echo $@ $(LP2PGOWRAPPER_DIFILES)
	@echo $@ $(DIFILES_tagion.crypto.secp256k1.c)

${call DDEPS,$(DBUILD),$(DFILES)}

endif

$(LINUX_X86_64)-%:
	$(MAKE) PLATFORM=$(LINUX_X86_64) $@

$(LINUX_X86_64):
	$(MAKE) PLATFORM=$(LINUX_X86_64)
