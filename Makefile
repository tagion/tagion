.SUFFIXES:
.ONESHELL:
.NOTPARALLEL:


DC=dmd
DCFLAGS=-O -d -m64 -i
DINC=nngd extern/libnng/libnng
DLFLAGS=-Lextern/libnng/extern/nng/build/lib/ -lnng

DTESTS=$(wildcard test/*.d)
DTARGETS=$(basename $(DTESTS))

all: lib test
	@echo "All done!"

test: $(DTESTS)

extern:
	git submodule update --init --checkout --recursive --remote --force && \
	$(MAKE) -C extern/

$(DTESTS): 
	$(DC) $(DCFLAGS) -of=$(basename $@) ${addprefix -I,$(DINC)} ${addprefix -L,$(DLFLAGS)} $@

lib: extern
	$(DC) $(DCFLAGS) -lib -of=build/libnngd.a -H -Hd=build/ ${addprefix -I,$(DINC)} ${addprefix -L,$(DLFLAGS)} nngd/nngd.d

clean: clean-extern clean-local

clean-local:
	rm -rf ./build && \
	rm -f $(DTARGETS) $(addsuffix .o,$(DTARGETS))

clean-extern:
	$(MAKE) -C extern/ clean 

.PHONY: all extern lib clean $(DTESTS)

