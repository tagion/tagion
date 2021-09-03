MAKE_GENERATED := $(DIR_TUB)/generated.mk

define gen.reset
${shell echo "# This file is generated." > $(MAKE_GENERATED)}
${shell echo "# Do not commit, do not change manually." >> $(MAKE_GENERATED)}
${shell echo "" >> $(MAKE_GENERATED)}
endef

define gen.line
${shell echo "${strip $1}" >> $(MAKE_GENERATED)}
endef

define gen.linetab
${shell echo "	${strip $1}" >> $(MAKE_GENERATED)}
endef

define gen.space
${shell echo "" >> $(MAKE_GENERATED)}
endef

define gen.include
${eval include $(MAKE_GENERATED)}
endef