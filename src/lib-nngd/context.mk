DSRC_NNGD := ${call dir.resolve}

NNGD_TEST_DFILES+=$(shell find $(DSRC_NNGD) -path "*/nngd/tests/*" -name "*.d" -a -not -name "nngtestutil.d")
NNGD_DFILES:=$(shell find . -type f -name "*.d" -a -not -path "*/tests/*")
NNGD_DINC:=$(DSRC_NNGD)nngd/ $(DSRC_NNGD)libnng/ $(DSRC_NNGD)/nngd/tests/
NNGD_BIN:=$(DTMP)/nng_test
NNGD_TEST:=$(patsubst $(DSRC_NNGD)nngd/tests/%,$(NNGD_BIN)/%,$(NNGD_TEST_DFILES:.d=))

nngd_test: $(NNGD_TEST)

.PHONY: nng_test

$(NNGD_BIN)/%: $(DSRC_NNGD)/nngd/tests/%.d nng $(NNGD_FILES) $(NNGD_BIN)/.way
	$(DC) -i -od=$(NNGD_BIN) -of$@ ${addprefix -L,$(LD_NNG)} ${addprefix -I,$(NNGD_DINC)} $<

env-nngd_test:
	$(PRECMD)
	echo NNGD_TEST_DFILES=$(NNGD_TEST_DFILES)
	echo NNGD_TEST=$(NNGD_TEST)
	echo DSRC_NNGD=$(DSRC_NNGD)
	echo NNGD_BIN=$(NNGD_BIN)

.PHONY: env-nng_test
