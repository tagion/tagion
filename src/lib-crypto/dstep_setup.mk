
DESTROOT:=tagion/crypto/secp256k1/c/

DSTEPINC+=../wrap-secp256k1/secp256k1/include/

HFILES+=${wildcard $(DSTEPINC)/*.h}

DIFILES:=${notdir $(HFILES)}
DIFILES1:=${DIFILES:.h=.di}
DIFILES2:=${addprefix $(DESTROOT),$(DIFILES1)}

DSTEPFLAGS+=${addprefix -I,$(DSTEPINC)}

DSTEP:=dstep
