
export GODEBUG=cgocheck=-1
WOLFSSL?=1
OLD?=1
ONETOOL?=1
DEBUGGER?=ddd

ifdef WOLFSSL
DFLAGS+=$(DVERSION)=TINY_AES
DFLAGS+=$(DVERSION)=WOLFSSL
SSLIMPLEMENTATION=$(LIBWOLFSSL)
else
SSLIMPLEMENTATION=$(LIBOPENSSL)
NO_WOLFSSL=-a -not -path "*/wolfssl/*"
endif

ifdef OLD
DFLAGS+=$(DVERSION)=OLD_TRANSACTION
endif
