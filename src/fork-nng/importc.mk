
NNG_CFILES:=$(shell find $(DSRC_NNG)/src -name "*.c" -a -not -path "*/test*" -a -not -name "*test.c" -a -not -path "*windows*" -a -not -name "*tls*"  -a -not -path "*zerotier*"  -a -not -name "pair.c" -a -not -name "tcp.c" -a -not -name "websocket.c" -a -not -name "options.c" -printf "%p ")
NNG_HFILES:=$(shell find $(DSRC_NNG) -name "*.h" -a -not -path "*tests*" -printf "%P ") 

#NNG_COPY_CFILES:=$(shell find src/ -name "*.c" -printf "cp %p %P\n"|awk '{gsub("/","_",$3); print $1, $2, $3;}')
NNG_IMPORTC_SRC:=$(DTMP)/nng/importc

NNG_IMPORTC_CFILES=$(shell find $(NNG_IMPORTC_SRC) -name "*.c" -a -not -path "*/test*" -a -not -name "*test.c" -a -not -path "*windows*" -a -not -name "*tls*"  -a -not -path "*zerotier*"  -a -not -name "pair.c" -a -not -name "tcp.c" -a -not -name "websocket.c" -a -not -name "options.c" -printf "%p ")
NNG_CINCS+=$(DSRC_NNG)/include
NNG_CINCS+=$(DSRC_NNG)/src
NNG_CINCS+=$(DSRC_NNG)/src/core
NNG_CINCS+=$(DSRC_NNG)/src/platform/posix
NNG_CINCS+=$(DSRC_NNG)/src/supplemental/http
NNG_CINCS+=$(DSRC_NNG)/src/supplemental/websocket
NNG_CINCS+=$(DSRC_NNG)/src/supplemental/base64
NNG_CFLAGS+=-DNNG_PLATFORM_POSIX
NNG_CFLAGS+=-DNNG_ENABLE_TLS=OFF
TMP_SCRIPT:=$(shell mktemp -q /tmp/make.XXXXXXXX.sh)


test35:
	@echo $(NNG_IMPORTC_SRC)

copy-nng: $(NNG_IMPORTC_SRC)/.way
	$(PRECMD)
	echo $(TMP_SCRIPT)
	find $(DSRC_NNG)/src -name "*.c" -printf "cp %p %P\n"|awk '{gsub("/","_",$$3); $$3="$(NNG_IMPORTC_SRC)/"$$3; print $$1,$$2,$$3;}' > $(TMP_SCRIPT)
	. $(TMP_SCRIPT)

env-nng-importc:
	$(PRECMD)
	$(call log.header, $@ :: env)
	$(call log.env, NNG_CFILES, $(NNG_CFILES))
	$(call log.env, NNG_INCS, $(NNG_INCS))
	$(call log.close)


nng-importc: copy-nng
	mkdir -p /tmp/importc
	echo $(NNG_IMPORTC_CFILES)
	dmd $(NNG_IMPORTC_CFILES) -cpp=dmpp -c -od=/tmp/importc $(addprefix -P=-I,$(NNG_CINCS)) $(addprefix -P=,$(NNG_CFLAGS)) -v

x-nng-importc:
	mkdir -p /tmp/importc
	dmd $(NNG_CFILES) -c -od=/tmp/importc $(addprefix -P=-I,$(NNG_CINCS)) $(addprefix -P=,$(NNG_CFLAGS)) -v
