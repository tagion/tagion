libtagion: $(DLIB)/libtagion.$(LIBEXT)
libtagion: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)
libtagion: DFILES:=${shell find $(DSRC) -name "*.d" -a -path "*/src/lib-*" -a -not -path "*/unitdata/*" -a -not -path "*/tests/*" -a -not -path "*/lib-betterc/*" $(NO_WOLFSSL) }

libmobile: $(DLIB)/libmobile.$(LIBEXT)
libmobile: LIBS+=$(LIBSECP256K1)
libmobile: DFLAGS+=$(DDEFAULTLIBSTATIC)
libmobile: DFILES:=${shell find $(DSRC)/lib-mobile -name "*.d"}
