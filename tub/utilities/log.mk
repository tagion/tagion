LOG_SEPARATOR=--------------------------------------------

SEP=--------------------------------------------

define log.header
echo "";
echo "$(LOG_SEPARATOR) $(strip $1)";
endef

define log.subheader
echo "$(LOG_SEPARATOR) $(strip $1)";
endef

define log.space
echo "";
endef

define log.close
echo "";
endef

define log.separator
echo "$(LOG_SEPARATOR)";
endef

define log.line
echo "$(strip $1)";
endef

define log.lines
echo -e ${word 1, $1} ${foreach LINE, ${filter-out ${word 1, $1}, $1}, "\n${strip $(LINE)}"};
endef

define log.kvp
printf "%-23s: %s\n" $(strip $1) $(strip $2);
endef

define log.printf
printf $1
endef

define log.help
printf "  %-20s : %s\n" $1 $2;
endef

define log.info
$(call log.header, Info)
echo "$(strip $1)";
endef

define log.warning
cat << EOF
$(call log.header, Warning)
$(strip $1)
EOF
endef

define log.error
cat << EOF
$(call log.header, Error)
"$(strip $1)"
EOF
endef

#
# Print
#

PRINT_SEPARATOR=~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

define print
${info }${info $(PRINT_SEPARATOR) ${strip $1}}${if $2,${info ${strip $2}}}${if $3,${info ${strip $3}}}${if $4,${info ${strip $4}}}${if $5,${info ${strip $5}}}${info $(PRINT_SEPARATOR)}${info }
endef

define warning
${info }${info $(PRINT_SEPARATOR) Warning}${info Problem: }${info ${strip $1}}${info Fix: }${info ${strip $2}}${info $(PRINT_SEPARATOR)}${info }
endef
