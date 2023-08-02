.SUFFIXES:
.ONESHELL:
.NOTPARALLEL:


DC=dmd
DCFLAGS=-O -d -m64 -i
DINC=nngd extern/libnng
DLFLAGS=-Lextern/libnng/extern/nng/build/lib/ -lnng

DTESTS=$(wildcard test/*.d)
DTARGETS=$(basename $(DTESTS))

all: lib test
	@echo "All done!"

test: $(DTESTS)

extern/libnng/.git:
	git submodule update --init --checkout --recursive --remote --force && \
	$(MAKE) -C extern/

$(DTESTS): 
	$(DC) $(DCFLAGS) -of=$(basename $@) ${addprefix -I,$(DINC)} ${addprefix -L,$(DLFLAGS)} $@

lib: extern/libnng/.git
	$(DC) $(DCFLAGS) -lib -od=build/ ${addprefix -I,$(DINC)} ${addprefix -L,$(DLFLAGS)} nngd/nngd.d

clean: clean-local

clean-local:
	rm -rf ./build && \
	rm -f $(DTARGETS) $(DTARGETS).o
 

.PHONY: all extern lib clean $(DTESTS)

