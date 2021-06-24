include $(DIR_SELF)/unittest_setup.mk

${info ${call log.info, $(DIR_SELF)}}
${warning ${call log.info, $(DIR_SELF)}}

HELP+=help-unittest
help-unittest:
	$(call echo.log.section.start, help :: unittest)
	$(call echo.log.section.item, make unittest, This will run unittest for all existing modules)
	$(call echo.log.section.end)

CLEAN+=clean-unittest
clean-unittest:

define UNITTEST
UNITTEST_MAKES+=unittest-$1
unittest-$1:
	$(MAKE) -C $1 unittest
endef

#UNITMAKE:=
${foreach subdir,$(UNITTEST_SUBMAKE),${eval ${call UNITTEST,$(subdir)}}}
#UNITMAKE:=${foreach subdir,$(UNITTEST_SUBMAKE),make -C $(subdir)X}

unittest: $(UNITTEST_MAKES)
	@echo $(UNITTEST_SUBMAKE)
#	@echo $(UNITTEST_MAKES)
#	@echo "$(UNITMAKE)"
