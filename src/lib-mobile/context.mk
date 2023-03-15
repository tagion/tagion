MOBILE-DFILES?=${shell find $(DSRC) -name "*.d" -a -path "*/src/lib-mobile/*"}

libmobile: LIBS += $(LIBSECP256K1_STATIC)
libmobile: DFLAGS+=$(DEFAULTLIBSTATIC)
libmobile: DFLAGS+=$(DVERSION)=TINY_AES
libmobile: # secp256k1
	$(PRECMD)
	$(DC) $(DFLAGS) -i ${addprefix -I,$(DINC)} $(LIBS) ${sort $(MOBILE-DFILES)} --shared -of=$(DLIB)/libtagionmobile.so

mobile-bin-test: LIBS += $(LIBSECP256K1_STATIC)
mobile-bin-test:
	$(PRECMD)
	$(DC) $(DFLAGS) -i ${addprefix -I,$(DINC)} $(LIBS) app.d ${sort $(MOBILE-DFILES)} -of=$(DBIN)/wallet_create
