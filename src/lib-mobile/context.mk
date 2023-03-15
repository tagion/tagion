MOBILE-DFILES?=${shell find $(DSRC) -name "*.d" -a -path "*/src/lib-mobile/*"}

mobile: secp256k1
	$(PRECMD)
	$(DC) $(DFLAGS) -i ${addprefix -I,$(DINC)} $(LIBS) ${sort $(MOBILE-DFILES)} --shared -of=$(DLIB)/libtagionmobile.so
