libmobile: DFILES?=${shell find $(DSRC) -name "*.d" -a -path "*/src/lib-mobile/*"}

libmobile: LIBS += $(LIBSECP256K1)
libmobile: DFLAGS+=$(DEFAULTLIBSTATIC)
libmobile: DFLAGS+=$(DVERSION)=TINY_AES
libmobile: # secp256k1
	$(PRECMD)
	$(DC) $(DFLAGS) -i ${addprefix -I,$(DINC)} $(LIBS) ${sort $(DFILES)} --shared -of=$(DLIB)/libtagionmobile.so

libmobile-bin-test: LIBS += $(LIBSECP256K1_STATIC)
libmobile-bin-test:
	$(PRECMD)
	$(DC) $(DFLAGS) -i ${addprefix -I,$(DINC)} $(LIBS) app.d ${sort $(DFILES)} -of=$(DBIN)/wallet_create
