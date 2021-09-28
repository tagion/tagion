MAKE_GENERATED := $(DIR_TUB)/__generated-targets.mk

include $(DIR_TUB)/compilation/generation/generation.mk

include $(DIR_TUB)/compilation/generation/targets/o.mk
include $(DIR_TUB)/compilation/generation/targets/lib.mk
include $(DIR_TUB)/compilation/generation/targets/bin.mk