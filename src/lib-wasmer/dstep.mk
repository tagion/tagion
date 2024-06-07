#
# wasmer DSTEP headers
#

WASMER_PACKAGE := tagion.wasmer.c
WASMER_ROOT := $(call dir.resolve, tagion/wasmer/c)
WASMER_DFILES  := $(shell find $(WASMER_DIROOT) -name "*.d")

WASMER_POSTCORRECT=${call dir.match, lib-wasmer/scripts}

$(WASMER_ROOT)/wasm.di: DSTEP_POSTCORRECT+=$(WASMER_POSTCORRECT)/correct_wasm.pl

$(WASMER_ROOT)/wasm.di: DSTEPFLAGS+=--global-import tagion.wasmer.c.wasm_types

$(WASMER_ROOT)/wasmer.di: DSTEPFLAGS+=--global-import tagion.wasmer.c.wasm

$(call DSTEP_DO,$(WASMER_PACKAGE),$(WASMER_CSRC),$(WASMER_ROOT),$(CRYPTO_DFILES))


