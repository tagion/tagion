.SUFFIXES:
.ONESHELL:
.NOTPARALLEL:


DC=dmd
DCFLAGS=-O -d -m64 -i
DINC=nngd extern/libnng/libnng
DLFLAGS=-Lextern/libnng/extern/nng/build/lib/ -lnng

DTESTS=$(wildcard test/test*.d)

all: lib test
	@echo "All done!"

test: $(DTESTS)

extern/libnng/.git:
	git submodule update --init --checkout --recursive --remote --force && \
	$(MAKE) -C extern/

$(DTESTS): 
	$(DC) $(DCFLAGS) -od=test/build -of=test/build/$(basename $@) ${addprefix -I,$(DINC)} -Itest ${addprefix -L,$(DLFLAGS)} $@

lib: extern
	$(DC) $(DCFLAGS) -lib -of=build/libnngd.a -H -Hd=build/ ${addprefix -I,$(DINC)} ${addprefix -L,$(DLFLAGS)} nngd/nngd.d

clean: clean-local

clean-local:
	rm -rf ./build && \
	rm -rf ./test/build 

clean-extern:
	$(MAKE) -C extern/ clean


proper: clean-extern
	find extern -name "*.a" -exec rm {} \;

.PHONY: all extern lib clean $(DTESTS)

