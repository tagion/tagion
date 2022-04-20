
TAGIONWAVE?=$(DBIN)/tagionwave
TAGIONBOOT?=$(DBIN)/tagionboot

DARTUTIL?=$(DBIN)/dartutil
HIBONUTIL?=$(DBIN)/hibonutil
TAGIONWALLET?=$(DBIN)/wallet

DARTBOOTRECORD = $(TESTBENCH)/bootrecord.hibon







# $1:number $2:pincode $3:name $4:amount
define CREATE_WALLET
${eval
# $(TEST_DIR)/.wallet$1: PINCODE=$2
# $(TEST_DIR)/.wallet$1: AMOUNT=$4
# $(TEST_DIR)/.wallet$1: NAME=invoice_$3
# $(TEST_DIR)/.wallet$1: INVOICE_FILE=$$(TEST_DIR)/invoice_$3.hibon

# WALLETS+=$$(TEST_DIR)/wallet$1
# INVOICES+=$$(TEST_DIR)/invoice_$3.hibon
TESTBENCH_$1=${abspath $2/$1}
INVOICES+=$$(TESTBENCH_$1)/invoice.hibon

$1: $$(TESTBENCH_$1)/.way
$1: $$(TESTBENCH_$1)/invoice.hibon

$$(TESTBENCH_$1)/invoice.hibon: $$(TESTBENCH_$1)/tagionwallet.json
	echo $(TAGIONWALLET) $$< -x $$(PINCODE) -c $$(NAME):$$(AMOUNT) -i $$@

$$(TESTBENCH_$1)/tagionwallet.json: $$(TESTBENCH_$1)/wallet-$1 $(TAGIONWALLET)
	echo $(TAGIONWALLET) $$@ --path $$< -O

$$(TESTBENCH_$1)/wallet-$1:
	echo	@cp -a $$(TESTBENCH_BIN)/$$(@F) $$@

}
endef

#include testbench_setup.mk

create-recorder: tools $(DARTBOOTRECORDER)
	$(PRECMD)$(TAGIONBOOT) $(INVOICES) -o $(DARTBOOTRECORDER)

create-invoices: tools $(INVOICES)

$(DARTBOOTRECORDER): $(INVOICES)
	$(PRECMD)$(TAGIONBOOT) $? -o $@

# info-testbench:
# 	@echo $(WALLET_CONFIGS)
# 	@echo ${WALLET_SUFFIX_LIST}
# 	@echo ${WALLET_SUFFIX}
# 	@echo ${MASTER_WALLETS}
# 	@echo "WALLETS =${WALLETS}"



# $$(TEST_DIR)/invoice_$3.hibon: $$(TEST_DIR)/tagionwallet$1.json
# 	@$$(TAGIONWALLET) $$< -x $2 -c $3:$4 -i $$(TEST_DIR)/invoice_$3.hibon

# $$(TEST_DIR)/tagionwallet$1.json: $$(TEST_DIR)/wallet$1
# 	@$$(TAGIONWALLET) $$@ --path $$< -O

# $$(TEST_DIR)/wallet$1: ##$$(TESTBENCH_BIN)/wallet$1/tagionwallet.hibon
# 	@cp -a $$(TESTBENCH_BIN)/$$(@F) $$@

env-testbench:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.kvp, TAGIONWAVE, $(TAGIONWAVE)}
	${call log.kvp, TAGIONBOOT, $(TAGIONBOOT)}
	${call log.kvp, DARTUTIL, $(DARTUTIL)}
	${call log.kvp, TAGIONWALLET, $(TAGIONWALLET)}
	${call log.kvp, HIBONUTIL, $(HIBONUTIL)}
	${call log.env, INVOICES, $(INVOICES)}
	${call log.close}

env: env-ddeps

# CLEANERS+=clean-testbench

# clean-testbench:
# 	rm -fR $(TEST_DIR)

# test77:
# 	@echo $(TEST77)
# 	@echo ${WALLET_SUFFIX_LIST}
# 	@echo ${WALLET_SUFFIX}
# 	@echo M ${MASTER_WALLETS}
# 	@echo X ${WALLETS}



# CLEANER+=clean-test
# clean-testbench:
# 	cd test; rm -fR *; rm -f .wallet*

#${call CREATE_WALLET,first,$(TESTBENCH)}
#${call CREATE_WALLET,second,$(TESTBENCH)}

${foreach wallet,$(WALLETS),${call CREATE_WALLET,$(wallet),$(TESTBENCH)}}
