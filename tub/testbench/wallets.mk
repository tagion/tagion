

DARTBOOTRECORD = $(TESTLOG)/bootrecord.hibon
DARTDB = $(TESTLOG)/dart.drt

WALLETFILES+=tagionwallet.hibon
WALLETFILES+=quiz.hibon
WALLETFILES+=device.hibon

define CREATE_WALLET
${eval
TESTLOG_$1=$${abspath $2/$1}
BASEWALLET_$1=$$(FUND)/$1

BASEWALLETFILES_$1=$${addprefix $$(BASEWALLET_$1)/,$$(WALLETFILES)}
TESTWALLETFILES_$1=$${addprefix $$(TESTLOG_$1)/,$$(WALLETFILES)}
WALLET_CONFIG_$1=$$(TESTLOG_$1)/tagionwallet.json
INVOICE_$1=$$(TESTLOG_$1)/invoice.hibon

STDINWALLET_$1=$$(BASEWALLET_$1)/wallet.stdin

INVOICES+=$$(INVOICE_$1)

.SECONDARY: $$(STDINWALLET_$1)
.SECONDARY: $$(BASEWALLETFILES_$1)
.SECONDARY: $$(TESTWALLETFILES_$1)
.SECONDARY: $$(WALLET_CONFIG_$1)

$1-wallet: | $$(TESTLOG_$1)/.way
$1-wallet: $$(INVOICE_$1)

.PHONY: $1-wallet

wallets: $1-wallet

$1-fundamental: $$(BASEWALLETFILES_$1)
.PHONY: $1-fundamental

$$(INVOICE_$1): $$(WALLET_CONFIG_$1)
	$$(PRECMD)
	$${call log.kvp, invoice $1}
	$$(TAGIONWALLET) $$< -x$$(PINCODE) -c $$(NAME):$$(AMOUNT) -i $$@

$1-config: $$(TESTWALLETFILES_$1)
.PHONY: $1-config

$$(WALLET_CONFIG_$1): $$(TESTLOG_$1)/tagionwallet.hibon
	$$(PRECMD)
	$${call log.kvp, $$(@F) $1}
	$$(TAGIONWALLET) $$@ --path $$(TESTLOG_$1) -O

$$(TESTLOG_$1)/tagionwallet.hibon: $$(BASEWALLET_$1)/tagionwallet.hibon
	$$(PRECMD)
	$${call log.kvp, $$(@F) $1}
	cp $$(BASEWALLETFILES_$1) $$(@D)

$$(BASEWALLET_$1)/tagionwallet.hibon: | target-tagionwallet
$$(BASEWALLET_$1)/tagionwallet.hibon: $$(STDINWALLET_$1)
	$$(PRECMD)
	$${call log.kvp, base-wallet $1}
	cd $$(BASEWALLET_$1)
	cat $$< | $$(TAGIONWALLET) >/dev/null

env-$1:
	$$(PRECMD)
	$${call log.header, $$@ :: env}
	$${call log.kvp, TESTLOG_$1 $$(TESTLOG_$1)}
	$${call log.kvp, BASEWALLET_$1 $$(BASEWALLET_$1)}
	$${call log.kvp, STDINWALLET_$1 $$(STDINWALLET_$1)}
	$${call log.kvp, WALLET_CONFIG_$1, $$(WALLET_CONFIG_$1)}
	$${call log.kvp, INVOICE_$1, $$(INVOICE_$1)}
	$${call log.env, TESTWALLETFILES_$1, $$(TESTWALLETFILES_$1)}
	$${call log.env, BASEWALLETFILES_$1, $$(BASEWALLETFILES_$1)}
	$${call log.close}

env-wallets: env-$1

help-$1:
	$$(PRECMD)
	$${call log.header, $$@ :: help}
	$${call log.help, "make env-$1", "Displays env for $1-wallet"}
	$${call log.help, "make $1-wallet", "Creates $1-wallet"}
	$${call log.help, "make clean-$1", "cleans $1-wallet"}
	$${call log.help, "make remove-$1", "This will remove the fundation wallet."}
	$${call log.help, "", "Except the key file $$(STDINWALLET_$1)"}
	$${call log.help, "make $1-fundamental", "Generate the fundamental wallet which is stored in repositore"}
	$${call log.close}

.PHONY: help-$1

help-testnet: help-$1

clean-$1:
	$$(PRECMD)
	$${call log.header, $$@ :: clean}
	$$(RMDIR) $$(TESTLOG_$1)
	$${call log.close}

.PHONY: clean-$1

clean-wallets: clean-$1

remove-$1: clean-$1
	$$(PRECMD)
	$${call log.header, $$@ :: remove}
	$$(RM) $$(BASEWALLETFILES_$1)
	$$(RM) $$(WALLET_CONFIG_$1)
	$${call log.close}

remove-wallets: remove-$1

proper: remove-wallets

.PHONY: remove-$1

}
endef


env-wallets:
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

.PHONY: env-testnet

env: env-wallets

help-wallets:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make testnet", "Runs the testnet"}
	${call log.help, "make wallets", "Will create all testwallets"}
	${call log.help, "make clean-wallets", "Cleans all the wallets"}
	${call log.help, "make remove-wallets", "Removes all the base wallets except for the .stdin files"}
	${call log.close}

.PHONY: help-wallets

help: help-wallets

.PHONY: clean-wallets

clean: clean-wallets

.PHONY: remove-wallets

help-boot:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make boot", "Will create DART boot recorder"}
	${call log.help, "make clean-boot", "Delete the boot recorder"}
	${call log.close}

.PHONY: help-boot

help: help-boot

env-boot:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.kvp, DARTBOOTRECORD, $(DARTBOOTRECORD)}
	${call log.env, INVOICES, $(INVOICES)}
	${call log.close}

.PHONY: env-boot

env: env-boot

boot: wallets target-tagionboot $(DARTBOOTRECORD)

$(DARTBOOTRECORD): |wallets target-tagionboot
$(DARTBOOTRECORD): $(INVOICES)
	$(PRECMD)
	${call log.header, $(@F) :: boot record}
	$(TAGIONBOOT) $(INVOICES) -o $@
	${call log.close}

clean-boot:
	$(PRECMD)
	${call log.header, $@ :: clean}
	$(RM) $(DARTBOOTRECORD)
	${call log.close}

clean: clean-boot

dart: boot
dart: target-dartutil
dart: $(DARTBOOTRECORD)
	$(PRECMD)
	${call log.header, $@ :: dart db}
	$(MKDIR) ${dir $(DARTDB)}
	$(DARTUTIL) --initialize -i $< --dartfilename $(DARTDB) -m
	${call log.close}

env-dart:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.kvp, DARTDB, $(DARTDB)}
	${call log.kvp, DARTBOOTRECORD, $(DARTBOOTRECORD)}
	${call log.close}

env: env-dart

.PHONY: env-dart

help-dart:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make dart", "Will creates DART from the boot recorder"}
	${call log.help, "make boot", "Will create DART boot recorder"}
	${call log.help, "make clean-dart", "Deletes the DART db"}
	${call log.help, "make clean-boot", "Deletes the boot recorder"}
	${call log.close}

help: help-dart

.PHONY: help-dart

clean-dart:
	$(PRECMD)
	${call log.header, $@ :: clean}
	$(RM) $(DARTDB)
	${call log.close}

clean: clean-dart

${foreach wallet,$(WALLETS),${call CREATE_WALLET,$(wallet),$(TESTLOG)}}
