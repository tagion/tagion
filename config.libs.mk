LIBTAGION:=$(DLIB)/libtagion.$(LIBEXT)

LIB_DINC=$(shell find $(DSRC) -maxdepth 1 -type d -path "*/src/lib-*" )

libtagion: DFLAGS+=$(DOUTDIR)=$(DOBJ)
libtagion: DFLAGS+=$(FULLY_QUALIFIED)
libtagion: DINC+=$(LIB_DINC)
libtagion: DFILES:=${shell find $(DSRC) -name "*.d" -a -path "*/src/lib-*" -a -not -path "*/unitdata/*" -a -not -path "*/tests/*" -a -not -path "*/lib-behaviour/*" -a -not -path "*/lib-betterc/*"}
libtagion: $(LIBTAGION) $(DFILES)
libtagion: revision

clean-libtagion:
	$(RM) $(LIBTAGION)

.PHONY: clean-libtagion
clean: clean-libtagion

LIBMOBILE:=$(DLIB)/libmobile.$(LIBEXT)
libmobile: DFLAGS+=-i
libmobile: DFLAGS+=$(GEN_CPP_HEADER_FILE)=$(DLIB)/libmobile.h
libmobile: DINC+=$(LIB_DINC)
libmobile: SECP256K1_SHARED=
libmobile: LIBS+=$(LIBSECP256K1_STATIC)
libmobile: DFILES:=${shell find $(DSRC)/ \( -path "*/lib-mobile/*" -o -path "*/lib-api/*" \) -a -name "*.d"}
libmobile: DFILES+=$(DSRC)/lib-tools/tagion/tools/revision.d

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
$(LIBBETTERC): revision
$(LIBBETTERC): secp256k1
libbetterc: DFILES:=${shell find $(DSRC) -name "*.d" -a -path "*/src/lib-betterc/*" -a -not -path "*/unitdata/*" -a -not -path "*/tests/*"}
libbetterc: DFLAGS+=-betterC
libbetterc: $(LIBBETTERC) $(DFILES)
libbetterc: LDFLAGS+=$(LD_SECP256K1)

clean-libbetterc:
	$(RM) $(LIBBETTERC)

.PHONY: clean-libbetterc
clean: clean-libbetterc


LIBTAUONAPI:=$(DLIB)/libtauonapi.$(LIBEXT)
libtauonapi: DFLAGS+=-i
libtauonapi: DFLAGS+=$(GEN_CPP_HEADER_FILE)=$(DLIB)/libtauonapi.h
libtauonapi: DINC+=$(LIB_DINC)
libtauonapi: SECP256K1_SHARED=
libtauonapi: LIBS+=$(LIBSECP256K1_STATIC)
libtauonapi: DFILES:=${shell find $(DSRC)/lib-api -name "*.d"}

$(LIBTAUONAPI): revision
$(LIBTAUONAPI): secp256k1
libtauonapi: $(LIBTAUONAPI) $(DFILES)
	
ifeq ($(PLATFORM),$(IOS_ARM64))
modify_rpath: $(LIBTAUONAPI)
	install_name_tool -id "@rpath/libtauonapi.dylib" $<


.PHONY: modify_rpath

libtauonapi: modify_rpath
endif

clean-libtauonapi:
	$(RM) $(LIBTAUONAPI)
.PHONY: clean-libtauonapi
clean: clean-libtauonapi
