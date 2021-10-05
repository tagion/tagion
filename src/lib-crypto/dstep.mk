
include dstep_setup.mk

info:
	@echo Ok
	@echo $(DSTEPFLAGS)
	@echo $(HFILES)
	@echo "DESTROOT=$(DESTROOT)"
	@echo $(DIFILES)
	@echo $(DIFILES1)
	@echo $(DIFILES2)

all: $(DESTROOT) $(DIFILES2)


$(DESTROOT)%.di: $(DSTEPINC)/%.h
	@echo "$< <- $@"
	$(DSTEP) $(DSTEPFLAGS) $< -o $@

$(DESTROOT):
	mkdir -p $@

clean:
	rm -fR $(DESTROOT)
