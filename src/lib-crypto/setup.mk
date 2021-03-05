include git.mk
-include $(REPOROOT)/localsetup.mk
PACKAGE:=crypto
include $(MAINROOT)/submodule_default_setup.mk

LIBS+=${call GETLIB,tagion_basic}
LIBS+=${call GETLIB,tagion_utils}
LIBS+=${call GETLIB,tagion_hibon}
#LIBS+=${call GETLIB,tagion_hashgraph}
#LIBS+=${call GETLIB,tagion_gossip}
#LIBS+=${call GETLIB,tagion_dart}
#LIBS+=${call GETLIB,tagion_services}

LIBS+=$(LIBSECP256K1)

LDCFLAGS+=$(LDCFLAGS_GMP)
LDCFLAGS+=$(LDCFLAGS_CRYPT)

-include dstep_setup.mk

ifdef OPENSSL_AES
SOURCEFLAGS+=-a -not -path "*/tiny_aes/*"
else
SOURCEFLAGS+=-a -not -path "*/openssl_aes/*"
DCFLAGS+=$(DVERSION)=TINY_AES
endif
