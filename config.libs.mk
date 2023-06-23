LIBTAGION:=$(DLIB)/libtagion.$(LIBEXT)

libtagion: DFILES:=${shell find $(DSRC) -name "*.d" -a -path "*/src/lib-*" -a -not -path "*/unitdata/*" -a -not -path "*/tests/*" -a -not -path "*/lib-betterc/*" $(NO_WOLFSSL) -a -not -path "*/lib-zmqd/*" -a -not -path "*/lib-demos/*" }
libtagion: $(LIBTAGION) $(DFILES)
libtagion: LIBS+=$(SSLIMPLEMENTATION) $(LIBSECP256K1) $(LIBP2PGOWRAPPER)

clean-libtagion:
	$(RM) $(LIBTAGION)

.PHONY: clean-libtagion
clean: clean-libtagion

LIBMOBILE:=$(DLIB)/libmobile.$(LIBEXT)
libmobile: $(LIBSECP256K1)
libmobile: LIBS+=$(LIBSECP256K1_STATIC)
libmobile: DFILES:=${shell find $(DSRC)/lib-mobile -name "*.d"}
libmobile: $(LIBMOBILE) $(DFILES)

clean-libmobile:
	$(RM) $(LIBMOBILE)

.PHONY: clean-libmobile
clean: clean-libmobile
