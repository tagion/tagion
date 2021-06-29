# include $(DIR_SELF)/unittest.mk

# define TESTMACRO
# ${eval ERR:=}
# ${eval OUT:=}
# cd .libs/$(@F);
# ls
# @echo $1
# @echo $(ERR)
# @echo $(OUT)
# endef



# I have all modules defined here, and also should have all modules resolved here
# Each module may  rely on other modules, and here we can show or even resolve
# dependencies

# Then we must collect all flags and D source files and compile

# Libraries are compiled as static or shared

# Bins as bins

# Platform is defined by ARCH variable (tripplet)

# make all (wrap first)
# make static-lib/some
# make static-wrap/secp256k1 TRIPLET=arm64-apple-darwin
# make shared-wrap/secp256k1 TRIPLET=arm64-apple-darwin

# ${info ${call _log.info, hello}}

# lib/%:
# 	${call log.info, some}

# libs:
# 	@echo $(DINC)
# 	${foreach MODULE,$(DINC), $(MAKE) -C $(MODULE) lib;}

# clean: $(CLEAN)
# 	rm -fR build
# 	${foreach MODULE,$(DINC), $(MAKE) -C $(MODULE) clean;}

# proper: $(CLEAN) $(PROPER)

# .PHONY: lib/%