# These targets should be run after a successful build
#

PKG_DIR=$(DBUILD)/tagion

bin-pkg:
	mkdir -p $(PKG_DIR)/usr/bin $(PKG_DIR)/etc/
	$(CP) $(DBIN)/tagion $(PKG_DIR)/usr/bin/
	$(PKG_DIR)/usr/bin/tagion -s
	$(CP) etc/neuewelle.service $(PKG_DIR)/etc/
	$(CP) etc/tagionshell.service $(PKG_DIR)/etc/

tar-pkg:
	$(CP) $(SCRIPTS)/install.sh $(PKG_DIR)/
	tar czf $(BUILD)/tagion-$(PLATFORM)-$(VERSION_REF).tar.gz --directory=$(DBUILD) tagion

deb-pkg:
	mkdir $(PKG_DIR)/DEBIAN
	envsubst < $(DTUB)/DEBIAN/control > $(PKG_DIR)/DEBIAN/control
	dpkg-deb --root-owner-group --build $(PKG_DIR)


lib-pkg:
	mkdir -p $(PKG_DIR)/usr/
	$(CP) -r $(DLIB) $(PKG_DIR)/usr/

clean-pkg:
	$(RM) -r $(PKG_DIR)
