#
# wasmer DSTEP headers
#

WASMER_PACKAGE := tagion.wasmer.c
WASMER_DIRROOT := $(call dir.resolve, tagion/wasmer/c)
WASMER_DFILES  := $(shell find $(WASMER_DIROOT) -name "*.d")

$(call DSTEP_DO,$(WASMER_PACKAGE),$(WASMER_CSRC),$(WASMER_DIRROOT),$(CRYPTO_DFILES))


