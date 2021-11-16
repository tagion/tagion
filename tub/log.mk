LOG_SEPARATOR=--------------------------------------------

define log.header
@echo "\n$(LOG_SEPARATOR) \033[4m$(strip $1)\033[0m"
endef

define log.subheader
@echo "$(LOG_SEPARATOR) \033[4m$(strip $1)\033[0m"
endef

define log.space
@echo "\n"
endef

define log.close
@echo "$(LOG_SEPARATOR)\n"
endef

define log.separator
@echo "$(LOG_SEPARATOR)"
endef

define log.line
@echo "$(strip $1)"
endef

define log.lines
@echo ${word 1, $1} ${foreach LINE, ${filter-out ${word 1, $1}, $1}, "\n${strip $(LINE)}"}
endef

define log.kvp
@echo "\033[1m$(strip $1)\033[0m: $(strip $2)"
endef

define log.info
$(call log.header, Info)
@echo "$(strip $1)"
endef

define log.warning
@echo "\033[33m"
$(call log.header, Warning)
@echo "$(strip $1)"
@echo "\033[0m"
endef

define log.error
@echo "\033[31m"
$(call log.header, Error)
@echo "$(strip $1)"
@echo "\033[0m"
endef

# 
# Print
# 

PRINT_SEPARATOR=~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

define print
${info }${info $(PRINT_SEPARATOR) ${strip $1}}${if $2,${info ${strip $2}}}${if $3,${info ${strip $3}}}${if $4,${info ${strip $4}}}${if $5,${info ${strip $5}}}${info $(PRINT_SEPARATOR)}${info }
endef