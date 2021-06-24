include $(DIR_SELF)/unittest.mk

define TESTMACRO
${eval ERR:=}
${eval OUT:=}
cd .libs/$(@F);
ls
@echo $1
@echo $(ERR)
@echo $(OUT)
endef

${info ${call _log.info, hello}}

lib/%:
	${call log.info, some}

libs:
	@echo $(DINC)
	${foreach MODULE,$(DINC), $(MAKE) -C $(MODULE) lib;}

clean: $(CLEAN)
	rm -fR build
	${foreach MODULE,$(DINC), $(MAKE) -C $(MODULE) clean;}

proper: $(CLEAN) $(PROPER)

.PHONY: lib/%