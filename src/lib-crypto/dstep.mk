
include dstep_setup.mk

dodi: $(DESTROOT) $(DIFILES)

info:
	@echo "HFILES    =$(HFILES)"
	@echo "DESTROOT  =$(DESTROOT)"
	@echo "DIFILES   =$(DIFILES)"
	@echo "DSTEPFLAGS=$(DSTEPFLAGS)"


$(DESTROOT)%.di: $(DSTEPINC)/%.h
	@echo "$< <- $@"
	@echo "$*"
	$(DSTEP) $(DSTEPFLAGS) --package "$(PACKAGE)" $< -o $@

$(DESTROOT):
	mkdir -p $@

clean:
	rm -fR $(DESTROOT)
