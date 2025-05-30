# These targets should be run after a successful build
#

PKG_DIR=$(DBUILD)/tagion

bin-pkg:
	mkdir -p $(PKG_DIR)/usr/bin $(PKG_DIR)/etc/
	$(CP) $(DBIN)/tagion $(PKG_DIR)/usr/bin/
	$(PKG_DIR)/usr/bin/tagion -s
	mkdir -p $(PKG_DIR)/etc/systemd/system/
	$(CP) etc/tagionshell.service etc/neuewelle.service $(PKG_DIR)/etc/systemd/system/

tar-pkg:
	$(CP) $(SCRIPTS)/install.sh $(PKG_DIR)/
	tar czf $(BUILD)/tagion-$(PLATFORM)-$(VERSION_REF).tar.gz --directory=$(DBUILD) tagion

deb-pkg:
	mkdir $(PKG_DIR)/DEBIAN
	envsubst < $(DTUB)/DEBIAN/control > $(PKG_DIR)/DEBIAN/control
	dpkg-deb --root-owner-group --build $(PKG_DIR) $(BUILD)/tagion-$(PLATFORM)-$(VERSION_REF).deb

lib-pkg:
	mkdir -p $(PKG_DIR)/usr/
	$(CP) -r $(DLIB) $(PKG_DIR)/usr/

clean-pkg:
	$(RM) -r $(PKG_DIR)
