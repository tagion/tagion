.SUFFIXES:
.ONESHELL:
.NOTPARALLEL:


DC=dmd
DINC=libnng

ifeq ($(NNG_WITH_MBEDTLS),ON)
	DCFLAGS=-O -d -m64 -i -version=withtls
	DLFLAGS=-Lextern/nng/build/lib/ -Lextern/mbedtls/build/target/lib/ -lnng -lmbedtls -lmbedcrypto -lmbedx509
else
	DCFLAGS=-O -d -m64 -i
	DLFLAGS=-Lextern/nng/build/lib/ -lnng
endif

DTESTS=$(wildcard tests/*.d)
DTARGETS=$(basename $(DTESTS))

all: lib test
	@echo "All done!"

test: extern $(DTESTS) asset

extern:
	git submodule update --init --recursive && \
	$(MAKE) -C extern/

$(DTESTS):
	$(DC) $(DCFLAGS) -od=build/tests -of=build/$(basename $@) ${addprefix -I,$(DINC)} ${addprefix -L,$(DLFLAGS)} $@

asset:
	cp -r tests/htdocs build/tests/

lib:
	$(DC) $(DCFLAGS) -lib -od=build/ -H -Hd=build/ ${addprefix -I,$(DINC)} ${addprefix -L,$(DLFLAGS)} libnng/libnng.d

clean: clean-local

proper: clean-local clean-extern

clean-local:
	rm -rf ./build && \
	rm -f $(DTARGETS) $(addsuffix .o,$(DTARGETS))

clean-extern:
	$(MAKE) clean -C extern/

update:
	git submodule update --remote --recursive

.PHONY: all extern lib clean update $(DTESTS)

