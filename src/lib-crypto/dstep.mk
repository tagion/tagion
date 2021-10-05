
include dstep_setup.mk

info:
	@echo "HFILES=$(HFILES)"
	@echo "DESTROOT=$(DESTROOT)"
	@echo "DIFILES=$(DIFILES)"
	@echo "DSTEPFLAGS=$(DSTEPFLAGS)"

all: $(DESTROOT) $(DIFILES)


$(DESTROOT)%.di: $(DSTEPINC)/%.h
	@echo "$< <- $@"
	$(DSTEP) $(DSTEPFLAGS) $< -o $@

$(DESTROOT):
	mkdir -p $@

clean:
	rm -fR $(DESTROOT)
