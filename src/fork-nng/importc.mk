
NNG_CFILES:=$(shell find $(DSRC_NNG)/src -name "*.c" -a -not -path "*/test*" -a -not -name "*test.c" -a -not -path "*windows*" -a -not -name "*tls*"  -a -not -path "*zerotier*" -printf "%p ")

NNG_CINCS+=$(DSRC_NNG)/include
NNG_CINCS+=$(DSRC_NNG)/src
NNG_CFLAGS+=-DNNG_PLATFORM_POSIX

env-nng-importc:
	$(PRECMD)
	$(call log.header, $@ :: env)
	$(call log.env, NNG_CFILES, $(NNG_CFILES))
	$(call log.env, NNG_INCS, $(NNG_INCS))
	$(call log.close)


nng-importc:
	mkdir -p /tmp/importc
	dmd $(NNG_CFILES) -c -od=/tmp/importc $(addprefix -P=-I,$(NNG_CINCS)) $(addprefix -P=,$(NNG_CFLAGS)) -v
