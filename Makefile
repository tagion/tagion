.SUFFIXES:
.ONESHELL:
.NOTPARALLEL:


DC=dmd
DCFLAGS=-O -d -m64 -i
DINC=libnng
DLFLAGS=-Lextern/nng/build/lib/ -lnng

DTESTS=$(wildcard test/*.d)
DTARGETS=$(basename $(DTESTS))

all: lib test
	@echo "All done!"

test: extern $(DTESTS)

extern:
	git submodule update --init --checkout --recursive --remote --force && \
	$(MAKE) -C extern/

$(DTESTS): 
	$(DC) $(DCFLAGS) -of=$(basename $@) ${addprefix -I,$(DINC)} ${addprefix -L,$(DLFLAGS)} $@

lib:
	$(DC) $(DCFLAGS) -lib -od=build/ ${addprefix -I,$(DINC)} ${addprefix -L,$(DLFLAGS)} libnng/libnng.d

clean: clean-local

clean-local:
	rm -rf ./build && \
	rm -f $(DTARGETS) $(DTARGETS).o
 

.PHONY: all extern lib clean $(DTESTS)

