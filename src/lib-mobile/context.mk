# libmobile: MOBILE-DFILES?=${shell find $(DSRC)/lib-mobile -name "*.d"}
# libmobile: DINC+=${shell find $(DSRC) -maxdepth 1 -type d -path "*src/lib-*" }
# libmobile: LIBS += $(LIBSECP256K1)
# libmobile: DFLAGS+=$(DDEFAULTLIBSTATIC)
# libmobile: DFLAGS+=$(DVERSION)=TINY_AES
# libmobile: secp256k1
# 	$(PRECMD)
# 	echo $(MOBILE-DFILES)
# 	echo $(DINC)
# 	$(DC) $(DFLAGS) -i ${addprefix -I,$(DINC)} $(LIBS) ${sort $(MOBILE-DFILES)} --shared -of=$(DLIB)/libtagionmobile.so
