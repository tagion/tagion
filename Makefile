.SUFFIXES:
.ONESHELL:
.NOTPARALLEL:


DC=dmd
DINC=libnng

ifdef NNG_WITH_MBEDTLS
	DCFLAGS=-O -d -m64 -i -version withtls
	DLFLAGS=-Lextern/nng/build/lib/ -Lextern/mbedtls/build/lib/ -lnng -lmbedtls -lmbedcrypto -lmbedx509
else
	DCFLAGS=-O -d -m64 -i
	DLFLAGS=-Lextern/nng/build/lib/ -lnng
endif

DTESTS=$(wildcard tests/*.d)
DTARGETS=$(basename $(DTESTS))

all: lib test
	@echo "All done!"

test: extern $(DTESTS)

extern:
	git submodule update --init --recursive && \
	$(MAKE) -C extern/

$(DTESTS): 
	$(DC) $(DCFLAGS) -of=$(basename $@) ${addprefix -I,$(DINC)} ${addprefix -L,$(DLFLAGS)} $@

lib:
	$(DC) $(DCFLAGS) -lib -od=build/ -H -Hd=build/ ${addprefix -I,$(DINC)} ${addprefix -L,$(DLFLAGS)} libnng/libnng.d

clean: clean-local

clean-local:
	rm -rf ./build && \
	rm -f $(DTARGETS) $(addsuffix .o,$(DTARGETS))
 

.PHONY: all extern lib clean $(DTESTS)

