.SUFFIXES:
.ONESHELL:
.NOTPARALLEL:

# default is ON
NNG_WITH_MBEDTLS?=ON

DC=dmd
DCFLAGS=-O -d -m64 -i -debug -g -gf -gs -gx -dip1000
DINC=nngd extern/libnng/libnng

DTESTS=$(wildcard tests/test*.d)

ifeq ($(NNG_WITH_MBEDTLS),ON)
	DCFLAGS=-O -d -m64 -i -debug -g -version=withtls
	DLFLAGS=-Lextern/libnng/extern/nng/build/lib/ -Lextern/libnng/extern/mbedtls/build/lib/ -lnng -lmbedtls -lmbedcrypto -lmbedx509
else
	DCFLAGS=-O -d -m64 -i -debug -g
	DLFLAGS=-Lextern/libnng/extern/nng/build/lib/ -lnng
endif


all: extern lib test
	@echo "All done!"

test: $(DTESTS)

extern:
	git submodule update --init --recursive && \
	$(MAKE) -C extern/

$(DTESTS):
	$(DC) $(DCFLAGS) -od=tests/build -of=tests/build/$(basename $@) ${addprefix -I,$(DINC)} -Itests ${addprefix -L,$(DLFLAGS)} $@

lib: 
	$(DC) $(DCFLAGS) -lib -of=build/libnngd.a -H -Hd=build/ ${addprefix -I,$(DINC)} ${addprefix -L,$(DLFLAGS)} nngd/nngd.d

clean: clean-extern clean-local

proper: proper-extern clean-local

clean-local:
	rm -rf ./build && \
	rm -rf ./tests/build

clean-extern:
	$(MAKE) clean -C extern/

proper-extern:
	$(MAKE) proper -C extern/

.PHONY: all extern lib clean $(DTESTS)

