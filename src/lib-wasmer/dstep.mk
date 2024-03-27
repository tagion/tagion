#
# wasmer DSTEP headers
#

WASMER_PACKAGE := tagion.wasmer.c
WASMER_ROOT := $(call dir.resolve, tagion/wasmer/c)
WASMER_DFILES  := $(shell find $(WASMER_DIROOT) -name "*.d")

$(call DSTEP_DO,$(WASMER_PACKAGE),$(WASMER_CSRC),$(WASMER_ROOT),$(CRYPTO_DFILES))


