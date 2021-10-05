
DESTROOT:=tagion/crypto/secp256k1/c/

DSTEPINC+=../wrap-secp256k1/secp256k1/include/

HFILES+=${wildcard $(DSTEPINC)/*.h}

HNOTDIR:=${notdir $(HFILES)}

DINOTDIR:=${HNOTDIR:.h=.di}

DIFILES2:=${addprefix $(DESTROOT),$(DINOTDIR)}
DIFILES:=${addprefix $(DESTROOT),$(DINOTDIR)}

DSTEPFLAGS+=${addprefix -I,$(DSTEPINC)}

DSTEP:=dstep
