LCRYPTO_DIROOT := ${call dir.resolve, tagion/crypto/secp256k1/c}
LCRYPTO_PACKAGE := tagion.crypto.secp256k1.c

LCRYPTO_DSTEPINC += $(DSRC_SECP256K1)/include
LCRYPTO_HFILES += ${wildcard $(LCRYPTO_DSTEPINC)/*.h}
LCRYPTO_HNOTDIR := ${notdir $(LCRYPTO_HFILES)}
LCRYPTO_DINOTDIR := ${LCRYPTO_HNOTDIR:.h=.di}
LCRYPTO_DIFILES := ${addprefix $(LCRYPTO_DIROOT)/,$(LCRYPTO_DINOTDIR)}

LCRYPTO_DSTEPFLAGS += ${addprefix -I,$(LCRYPTO_DSTEPINC)}
LCRYPTO_DSTEPFLAGS += --global-attribute=nothrow
LCRYPTO_DSTEPFLAGS += --global-attribute=@nogc

TOCLEAN += $(LCRYPTO_DIFILES)

$(LCRYPTO_DIROOT)/secp256k1_ecdh.di: LCRYPTO_DSTEPFLAGS += --global-import=$(LCRYPTO_PACKAGE).secp256k1

# Target for creating di local to this unit
$(LCRYPTO_DIROOT)/%.di: $(LCRYPTO_DSTEPINC)/%.h $(LCRYPTO_DIROOT)/%.way
	${call log.kvp, $*.di}
	${call log.lines, $<}
	${call log.lines, $@}
	$(PRECMD)$(DSTEP) $(LCRYPTO_DSTEPFLAGS) --package "$(LCRYPTO_PACKAGE)" $< -o $@

MAKE_SHOW_ENV += env-libcrypto-dstep
env-libcrypto-dstep:
	$(call log.header, env :: libscrypto :: dstep)
	${call log.kvp, HFILES, $(HFILES)}
	${call log.kvp, DESTROOT, $(DESTROOT)}
	${call log.kvp, DIFILES, $(DIFILES)}
	${call log.kvp, DSTEPFLAGS, $(DSTEPFLAGS)}
	$(call log.close)