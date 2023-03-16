libmobile: MOBILE-DFILES?=${shell find $(DSRC) -name "*.d" -a -path "*/src/lib-mobile/*"}

libmobile: LIBS += $(LIBSECP256K1)
libmobile: DFLAGS+=$(DDEFAULTLIBSTATIC)
libmobile: DFLAGS+=$(DVERSION)=TINY_AES
libmobile: DFLAGS+=$(DINCIMPORT)
libmobile: # secp256k1
	$(PRECMD)
	$(DC) $(DFLAGS) ${addprefix -I,$(DINC)} $(LIBS) ${sort $(MOBILE-DFILES)} --shared -of=$(DLIB)/libtagionmobile.so

libmobile-bin-test: LIBS += $(LIBSECP256K1_STATIC)
libmobile-bin-test:
	$(PRECMD)
	$(DC) $(DFLAGS) ${addprefix -I,$(DINC)} $(LIBS) app.d ${sort $(MOBILE-DFILES)} -of=$(DBIN)/wallet_create
