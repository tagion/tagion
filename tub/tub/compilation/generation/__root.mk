MAKE_GENERATED := $(DIR_TUB)/__generated-targets.mk

include $(DIR_TUB)/compilation/generation/generation.mk

include $(DIR_TUB)/compilation/generation/targets/__root.mk