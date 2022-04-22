
TAGIONWAVE?=$(DBIN)/tagionwave
TAGIONBOOT?=$(DBIN)/tagionboot

DARTUTIL?=$(DBIN)/dartutil
HIBONUTIL?=$(DBIN)/hibonutil
TAGIONWALLET?=$(DBIN)/wallet

DARTBOOTRECORD = $(TESTBENCH)/bootrecord.hibon







# $1:name $2:testbench-path
define CREATE_WALLET
${eval
# $(TEST_DIR)/.wallet$1: PINCODE=$2
# $(TEST_DIR)/.wallet$1: AMOUNT=$4
# $(TEST_DIR)/.wallet$1: NAME=invoice_$3
# $(TEST_DIR)/.wallet$1: INVOICE_FILE=$$(TEST_DIR)/invoice_$3.hibon

# WALLETS+=$$(TEST_DIR)/wallet$1
# INVOICES+=$$(TEST_DIR)/invoice_$3.hibon
TESTBENCH_$1=${abspath $2/$1}
BASEWALLET_$1=$$(FUND)/$1
WALLETFILES_$1+=$$(BASEWALLET_$1)/tagionwallet.hibon
WALLETFILES_$1+=$$(BASEWALLET_$1)/quiz.hibon
WALLETFILES_$1+=$$(BASEWALLET_$1)/device.hibon

STDINWALLET_$1=$$(BASEWALLET_$1)/wallet.stdin
INVOICES+=$$(TESTBENCH_$1)/invoice.hibon

.SECONDARY: $$(STDINWALLET_$1)

$1-wallet: $$(TESTBENCH_$1)/.way
$1-wallet: $$(TESTBENCH_$1)/invoice.hibon

$1-fundamental: $$(WALLETFILES_$1)

$$(TESTBENCH_$1)/invoice.hibon: $$(TESTBENCH_$1)/tagionwallet.json
	echo $$(TAGIONWALLET) $$< -x $$(PINCODE) -c $$(NAME):$$(AMOUNT) -i $$@

$$(TESTBENCH_$1)/tagionwallet.json: $$(TESTBENCH_$1)/wallet
	echo $$(TAGIONWALLET) $$@ --path $$< -O

$$(TESTBENCH_$1)/wallet: $$(STDINWALLET_$1)
	echo	@cp -a $$(TESTBENCH_BIN)/$$(@F) $$@

$$(WALLETFILES_$1): $$(STDINWALLET_$1)
	$$(PRECMD)
	cd $$(BASEWALLET_$1)
	cat $$< | $$(TAGIONWALLET)

$$(STDINWALLET_$1): $$(BASEWALLET_$1)/.way  target-wallet
	$$(PRECMD)
	cd $$(BASEWALLET_$1)
	tee $$(STDINWALLET_$1) < /dev/stdin | $$(TAGIONWALLET)

env-$1:
	$$(PRECMD)
	$${call log.header, $$@ :: env}
	$${call log.kvp, TESTBENCH_$1 $$(TESTBENCH_$1)}
	$${call log.kvp, BASEWALLET_$1 $$(BASEWALLET_$1)}
	$${call log.kvp, STDIWALLET_$1 $$(STDIWALLET_$1)}
	$${call log.close}

env-testbench: env-$1

help-$1:
	$$(PRECMD)
	$${call log.header, $$@ :: help}
	$${call log.help, "make env-$1", "Displays env for $1-wallet"}
	$${call log.help, "make $1-wallet", "Creates $1-wallet"}
	$${call log.help, "make clean-$1", "cleans $1-wallet"}
	$${call log.help, "make $1-fundamental", "Generate the fundamental wallet which is stored in repositore"}
	$${call log.close}

help-testbench: help-$1

.PHONY: help-$1
}
endef

#include testbench_setup.mk

create-recorder: tools $(DARTBOOTRECORDER)
	$(PRECMD)$(TAGIONBOOT) $(INVOICES) -o $(DARTBOOTRECORDER)

create-invoices: tools $(INVOICES)

$(DARTBOOTRECORDER): $(INVOICES)
	$(PRECMD)$(TAGIONBOOT) $? -o $@

env-testbench:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.kvp, TAGIONWAVE, $(TAGIONWAVE)}
	${call log.kvp, TAGIONBOOT, $(TAGIONBOOT)}
	${call log.kvp, DARTUTIL, $(DARTUTIL)}
	${call log.kvp, TAGIONWALLET, $(TAGIONWALLET)}
	${call log.kvp, HIBONUTIL, $(HIBONUTIL)}
	${call log.kvp, DARTBOOTRECORD, $(DARTBOOTRECORD)}
	${call log.env, INVOICES, $(INVOICES)}
	${call log.close}

.PHONY: env-testbench

env: env-testbench

help-testbench:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make testbench", "Runs the testbench"}
	${call log.help, "make clean-testbench", "Cleans all the wallets"}
	${call log.close}

.PHONY: help-testbench

help: help-testbench

clean-testbench:
	$(PRECMD)
	${call log.header, $@ :: clean}
	$(RMDIR) $(TESTBENCH)
	${call log.close}

.PHONY: clean-testbench

clean: clean-testbench

${foreach wallet,$(WALLETS),${call CREATE_WALLET,$(wallet),$(TESTBENCH)}}
