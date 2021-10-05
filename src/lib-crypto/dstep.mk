
include dstep_setup.mk

all: $(DESTROOT) $(DIFILES)

info:
	@echo "HFILES    =$(HFILES)"
	@echo "DESTROOT  =$(DESTROOT)"
	@echo "DIFILES   =$(DIFILES)"
	@echo "DSTEPFLAGS=$(DSTEPFLAGS)"


$(DESTROOT)%.di: $(DSTEPINC)/%.h
	@echo "$< <- $@"
	$(DSTEP) $(DSTEPFLAGS) $< -o $@

$(DESTROOT):
	mkdir -p $@

clean:
	rm -fR $(DESTROOT)
