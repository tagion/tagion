LIBTAGION:=$(DLIB)/libtagion.$(LIBEXT)

libtagion: DFILES:=${shell find $(DSRC) -name "*.d" -a -path "*/src/lib-*" -a -not -path "*/unitdata/*" -a -not -path "*/tests/*" -a -not -path "*/lib-behaviour/*" -a -not -path "*/lib-betterc/*"}
libtagion: $(LIBTAGION) $(DFILES)

clean-libtagion:
	$(RM) $(LIBTAGION)

.PHONY: clean-libtagion
clean: clean-libtagion

LIBMOBILE:=$(DLIB)/libmobile.$(LIBEXT)
libmobile: DFLAGS+=-i
libmobile: LIBS+=$(LIBSECP256K1_STATIC)
libmobile: DFILES:=${shell find $(DSRC)/lib-mobile -name "*.d"}

$(LIBMOBILE): revision
$(LIBMOBILE): secp256k1
libmobile: $(LIBMOBILE) $(DFILES)

ifeq ($(PLATFORM),$(IOS_ARM64))
modify_rpath: $(LIBMOBILE)
	install_name_tool -id "@rpath/libmobile.dylib" $<


.PHONY: modify_rpath

libmobile: modify_rpath
endif


clean-libmobile:
	$(RM) $(LIBMOBILE)

.PHONY: clean-libmobile
clean: clean-libmobile

LIBBETTERC:=$(DLIB)/libbetterc.$(LIBEXT)
$(LIBBETTERC): secp256k1
libbetterc: DFILES:=${shell find $(DSRC) -name "*.d" -a -path "*/src/lib-betterc/*" -a -not -path "*/unitdata/*" -a -not -path "*/tests/*"}
libbetterc: DFLAGS+=-i
libbetterc: DFLAGS+=-betterC
libbetterc: $(LIBBETTERC) $(DFILES)
libbetterc: LDFLAGS+=$(LD_SECP256K1)

clean-libbetterc:
	$(RM) $(LIBBETTERC)

.PHONY: clean-libbetterc
clean: clean-libbetterc
