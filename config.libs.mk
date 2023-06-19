LIBTAGION:=$(DLIB)/libtagion.$(LIBEXT)

libtagion: DFILES:=${shell find $(DSRC) -name "*.d" -a -path "*/src/lib-*" -a -not -path "*/unitdata/*" -a -not -path "*/tests/*" -a -not -path "*/lib-betterc/*" $(NO_WOLFSSL) -a -not -path "*/lib-zmqd/*" -a -not -path "*/lib-demos/*" }
libtagion: $(LIBTAGION) $(DFILES)
libtagion: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)

clean-libtagion:
	$(RM) $(LIBTAGION)

.PHONY: clean-libtagion
clean: clean-libtagion

libmobile: $(DLIB)/libmobile.$(LIBEXT)
libmobile: LIBS+=$(LIBSECP256K1)
libmobile: DFLAGS+=$(DDEFAULTLIBSTATIC)
libmobile: DFILES:=${shell find $(DSRC)/lib-mobile -name "*.d"}
