MAKE_GENERATED_TARGETS_O := $(DIR_TUB)/__generated-o.mk
MAKE_GENERATED_TARGETS_BIN := $(DIR_TUB)/__generated-bin.mk
MAKE_GENERATED_TARGETS_LIB := $(DIR_TUB)/__generated-lib.mk
MAKE_GENERATED_TARGETS_TEST := $(DIR_TUB)/__generated-test.mk
MAKE_GENERATED_LOGS := $(DIR_TUB)/__generated-logs.mk

# Line
define gen.o.line
${shell echo "${strip $1}" >> ${MAKE_GENERATED_TARGETS_O}}
endef

define gen.bin.line
${shell echo "${strip $1}" >> ${MAKE_GENERATED_TARGETS_BIN}}
endef

define gen.lib.line
${shell echo "${strip $1}" >> ${MAKE_GENERATED_TARGETS_LIB}}
endef

define gen.test.line
${shell echo "${strip $1}" >> ${MAKE_GENERATED_TARGETS_TEST}}
endef

define gen.logs.line
${shell echo "${strip $1}" >> ${MAKE_GENERATED_LOGS}}
endef

# Linetab
define gen.o.linetab
${shell echo "	${strip $1}" >> ${MAKE_GENERATED_TARGETS_O}}
endef

define gen.bin.linetab
${shell echo "	${strip $1}" >> ${MAKE_GENERATED_TARGETS_BIN}}
endef

define gen.lib.linetab
${shell echo "	${strip $1}" >> ${MAKE_GENERATED_TARGETS_LIB}}
endef

define gen.test.linetab
${shell echo "	${strip $1}" >> ${MAKE_GENERATED_TARGETS_TEST}}
endef

define gen.logs.linetab
${shell echo "	${strip $1}" >> ${MAKE_GENERATED_LOGS}}
endef

# Including generated
define gen.include
${eval -include $(MAKE_GENERATED_LOGS)}
${eval -include $(MAKE_GENERATED_TARGETS_O)}
${eval -include $(MAKE_GENERATED_TARGETS_LIB)}
${eval -include $(MAKE_GENERATED_TARGETS_BIN)}
${eval -include $(MAKE_GENERATED_TARGETS_TEST)}
endef

# Reset
define gen.reset
${eval ${call gen.reset.single, ${MAKE_GENERATED_LOGS}}}
${eval ${call gen.reset.single, ${MAKE_GENERATED_TARGETS_O}}}
${eval ${call gen.reset.single, ${MAKE_GENERATED_TARGETS_LIB}}}
${eval ${call gen.reset.single, ${MAKE_GENERATED_TARGETS_BIN}}}
${eval ${call gen.reset.single, ${MAKE_GENERATED_TARGETS_TEST}}}
endef

define gen.reset.single
${shell echo "# This file is generated." > ${strip $1}}
${shell echo "# Do not commit, do not change manually." >> ${strip $1}}
${shell echo "" >> ${strip $1}}
endef