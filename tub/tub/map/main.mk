# 
# First step is to collect all contexts
# 
CONTEXTS := ${shell find $(DIR_SRC) -name '*context.mk'}

# WRAPS :=
# LIBS :=
# BINS :=

# NEED_WRAPS :=
# NEED_LIBS :=

include $(CONTEXTS)

# NEED_WRAPS += $(WRAPS)
# NEED_LIBS += $(LIBS)

# $(eval NEED_WRAPS := $(foreach X, $(NEED_WRAPS), $(eval NEED_WRAPS := $(filter-out $X, $(NEED_WRAPS)) $X))$(NEED_WRAPS))
# $(eval NEED_LIBS := $(foreach X, $(NEED_LIBS), $(eval NEED_LIBS := $(filter-out $X, $(NEED_LIBS)) $X))$(NEED_LIBS))

# $(eval WRAPS := $(foreach X, $(WRAPS), $(eval WRAPS := $(filter-out $X, $(WRAPS)) $X))$(WRAPS))
# $(eval LIBS := $(foreach X, $(LIBS), $(eval LIBS := $(filter-out $X, $(LIBS)) $X))$(LIBS))
# $(eval BINS := $(foreach X, $(BINS), $(eval BINS := $(filter-out $X, $(BINS)) $X))$(BINS))

# LIBS := $(sort $(LIBS))
# NEED_LIBS := $(sort $(NEED_LIBS))

# LIBS_RESOLVED := $(filter $(NEED_LIBS), $(LIBS))
# LIBS_NOT_RESOLVED := $(filter-out $(LIBS), $(NEED_LIBS))

# Find all d files, using ONLY=

# 
# Second step is to build a map of what we need to compile
# 

# If ONLY is not specified explicitly, we will build everything
# ONLY ?= $(NEED_LIBS)



# Now let's define the scope we need to include in this compilation

# map:
# 	$(call log.header, map)
# 	$(call log.subheader, resolved)
# 	@echo ${word 1, $(LIBS_RESOLVED)} ${foreach LINE, ${filter-out ${word 1, $(LIBS_RESOLVED)}, $(LIBS_RESOLVED)}, "\n${strip $(LINE)}"}
# 	$(call log.subheader, not resolved)
# 	@echo ${word 1, $(LIBS_NOT_RESOLVED)} ${foreach LINE, ${filter-out ${word 1, $(LIBS_NOT_RESOLVED)}, $(LIBS_NOT_RESOLVED)}, "\n${strip $(LINE)}"}
# 	$(call log.close)

SOME=hello0

# lib/all: $(LIBS)
# 	$(call log.header, building lib/$(@F))
# 	$(call log.line, all dependencies are present for _$(@D)_$(@F))
# 	$(call log.line, $(SOME))
# 	$(call log.line, $(DEPS))
# 	$(call log.close)

define find_d_files
${shell find $(DIR_SRC)/lib_${strip $1} -name '*.d'}
endef

# With wrap work differently - point to it as dependency and resolve it here

wrap/%:
	@echo todo

lib/%: ctx/lib/%
	$(call log.header, building lib/$(@F))

	${eval LIBS += $(@F)}

	$(eval WRAPS := $(foreach X, $(WRAPS), $(eval WRAPS := $(filter-out $X, $(WRAPS)) $X))$(WRAPS))
	$(eval LIBS := $(foreach X, $(LIBS), $(eval LIBS := $(filter-out $X, $(LIBS)) $X))$(LIBS))

	$(call log.line, All dependencies of lib/$(@F) are present)
	$(call log.kvp, wraps, $(WRAPS))
	$(call log.kvp, libs, $(LIBS))
	${eval DFILES := ${foreach LIB, $(LIBS), ${call find_d_files, $(LIB)}}}
	
	$(call log.separator)
	${eval COMPILE_CMD := $(DC) $(DCFLAGS) $(INCFLAGS) $(DFILES) $(LDCFLAGS) -c -of$(DIR_BUILD)/libs/lib_$(@F).a}
	$(call log.kvp, Compiler, $(DC))
	$(call log.kvp, DCFLAGS, $(DCFLAGS))
	$(call log.kvp, LDCFLAGS, $(LDCFLAGS))
	$(call log.kvp, INCFLAGS, $(INCFLAGS))
	$(call log.kvp, DIR_BUILD, $(DIR_BUILD)/$@)
	$(call log.kvp, D Files)
	$(call log.lines, $(DFILES))
	$(call log.separator)

	$(call log.line, Compiling...)
	$(call log.space)
	@$(COMPILE_CMD)
	$(call log.close)

map:
	$(call log.header, map)
	$(call log.line, $(LIBS))
	$(call log.close)

.PHONY: map