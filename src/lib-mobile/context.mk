libmobile: MOBILE-DFILES?=${shell find $(DSRC) -name "*.d" -a -path "*/src/lib-mobile/*"}

libmobile: LIBS += $(LIBSECP256K1)
libmobile: DFLAGS+=$(DDEFAULTLIBSTATIC)
libmobile: DFLAGS+=$(DVERSION)=TINY_AES
libmobile: # secp256k1
	$(PRECMD)
	$(DC) $(DFLAGS) -i ${addprefix -I,$(DINC)} $(LIBS) ${sort $(MOBILE-DFILES)} --shared -of=$(DLIB)/libtagionmobile.so
