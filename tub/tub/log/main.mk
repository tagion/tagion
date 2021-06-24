# 
# Log
# 

LOG_SEPARATOR=--------------------------------------------

define log.open
@echo "\n$(LOG_SEPARATOR) \033[4m$(strip $1)\033[0m"
endef

define log.close
@echo "$(LOG_SEPARATOR)\n"
endef

define log.separator
@echo "$(LOG_SEPARATOR)"
endef

define log.kvp
@echo "\033[1m$(strip $1)\033[0m: $(strip $2)"
endef

define log.info
$(call log.open, Info)
@echo "$(strip $1)"
endef

define log.warning
@echo "\033[33m"
$(call log.open, Warning)
@echo "$(strip $1)"
@echo "\033[0m"
endef

define log.error
@echo "\033[31m"
$(call log.open, Error)
@echo "$(strip $1)"
@echo "\033[0m"
endef

# 
# Print
# 

PRINT_SEPARATOR=::::::::::::::::::::::::::::::::::::::::::::

define print
${info $(PRINT_SEPARATOR) }${info $(strip $1)}${info $(PRINT_SEPARATOR)}
endef