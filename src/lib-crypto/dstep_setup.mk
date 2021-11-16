
DESTROOT:=tagion/crypto/secp256k1/c/
PACKAGE:=tagion.crypto.secp256k1.c

DSTEPINC+=../wrap-secp256k1/secp256k1/include/

HFILES+=${wildcard $(DSTEPINC)/*.h}

HNOTDIR:=${notdir $(HFILES)}

DINOTDIR:=${HNOTDIR:.h=.di}

DIFILES2:=${addprefix $(DESTROOT),$(DINOTDIR)}
DIFILES:=${addprefix $(DESTROOT),$(DINOTDIR)}

DSTEPFLAGS+=${addprefix -I,$(DSTEPINC)}
DSTEPFLAGS+=--global-attribute=nothrow
DSTEPFLAGS+=--global-attribute=@nogc

DSTEP:=dstep


$(DESTROOT)secp256k1_ecdh.di: DSTEPFLAGS+=--global-import=$(PACKAGE).secp256k1
