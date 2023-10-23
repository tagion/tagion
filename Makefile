.SUFFIXES:
.ONESHELL:
.NOTPARALLEL:


DC=dmd
DCFLAGS=-O -d -m64 -i -debug -g
DINC=nngd extern/libnng/libnng
DLFLAGS=-Lextern/libnng/extern/nng/build/lib/ -Lextern/libnng/extern/mbedtls/build/lib/ -lnng -lmbedtls -lmbedcrypto -lmbedx509

DTESTS=$(wildcard tests/test*.d)

all: lib test
	@echo "All done!"

test: $(DTESTS)

extern:
	git submodule update --init --recursive && \
	$(MAKE) -C extern/

$(DTESTS): 
	$(DC) $(DCFLAGS) -od=tests/build -of=tests/build/$(basename $@) ${addprefix -I,$(DINC)} -Itests ${addprefix -L,$(DLFLAGS)} $@

lib: extern
	$(DC) $(DCFLAGS) -lib -of=build/libnngd.a -H -Hd=build/ ${addprefix -I,$(DINC)} ${addprefix -L,$(DLFLAGS)} nngd/nngd.d

clean: clean-extern clean-local

clean-local:
	rm -rf ./build && \
	rm -rf ./tests/build 

clean-extern:
	$(MAKE) -C extern/ clean 

.PHONY: all extern lib clean $(DTESTS)

