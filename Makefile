.SUFFIXES:
.ONESHELL:
.NOTPARALLEL:


DC=dmd
DCFLAGS=-O -d -m64 -i
DINC=libnng
DLFLAGS=-Lextern/nng/build/lib/ -lnng

DTESTS=$(wildcard test/*.d)
DTARGETS=$(basename $(DTESTS))

all: test

test: extern $(DTESTS)

extern:
	$(MAKE) -C extern/

$(DTESTS): 
	$(DC) $(DCFLAGS) -of=$(basename $@) ${addprefix -I,$(DINC)} ${addprefix -L,$(DLFLAGS)} $@

clean: clean-local

clean-local:
	rm $(DTARGETS) $(DTARGETS).o
 

.PHONY: all extern clean $(DTESTS)

