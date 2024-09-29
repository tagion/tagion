.SUFFIXES:
.ONESHELL:
.NOTPARALLEL:

# default is ON
NNG_WITH_MBEDTLS?=ON

DC=dmd
DCFLAGS=-O -d -m64 -i -debug -g -gf -gs -gx -dip1000
DINC=nngd extern/libnng/libnng

DTESTS=$(wildcard tests/test*.d)
RUNTESTS=$(basename $(DTESTS))

ifeq ($(NNG_WITH_MBEDTLS),ON)
	DCFLAGS=-O -d -m64 -i -debug -g -version=withtls
	DLFLAGS=-Lextern/libnng/extern/nng/build/lib/ -Lextern/libnng/extern/mbedtls/build/target/lib/ -lnng -lmbedtls -lmbedcrypto -lmbedx509
else
	DCFLAGS=-O -d -m64 -i -debug -g
	DLFLAGS=-Lextern/libnng/extern/nng/build/lib/ -lnng
endif


all: extern mime lib buildtest
	@echo "All done!"

buildtest: $(DTESTS)

extern:
	git submodule update --init --recursive && \
	$(MAKE) -C extern/

$(DTESTS):
	$(DC) $(DCFLAGS) -od=tests/build -of=tests/build/$(basename $@) ${addprefix -I,$(DINC)} -Itests ${addprefix -L,$(DLFLAGS)} $@

mime:
	@curl -s -K mime.list  |\
	awk -f mime.awk > nngd/mime.new && wc -l nngd/mime.new |\
	cut -d " " -f 1 |\
	awk '{if($$1 > 5) print "mv nngd/mime.new nngd/mime.d";}' |\
	sh && rm -f nngd/mime.new || true
lib: 
	$(DC) $(DCFLAGS) -lib -of=build/libnngd.a -H -Hd=build/ ${addprefix -I,$(DINC)} ${addprefix -L,$(DLFLAGS)} nngd/nngd.d

test: pretest $(RUNTESTS) posttest

pretest:
	@echo "It will take about a minute. Be patient."
	rm -f logs/*

posttest:
	@echo "."
	@grep -a '#TEST' logs/runtest.log |grep -q ERROR && echo "There are errors. See runtest.log" || echo "All passed!"

.SILENT: $(RUNTESTS)

$(RUNTESTS):
	NNG_DEBUG=TRUE tests/build/$@ >> logs/runtest.log
	@echo -n "."

clean: clean-extern clean-local

proper: proper-extern clean-local

clean-local:
	rm -f ./nngd/mime.d && \
	rm -f ./logs/* && \
	rm -rf ./build && \
	rm -rf ./tests/build

clean-extern:
	$(MAKE) clean -C extern/

proper-extern:
	$(MAKE) proper -C extern/

.PHONY: all extern mime lib clean $(DTESTS) $(RUNTESTS)
