clean-devnet-genesis:
	$(PRECMD)rm -rf $(DDEVNET)/genesis

clean-devnet-wallets:
	$(PRECMD)rm -rf $(DDEVNET)/wallets


devnet-genesis: devnet-wallet-1 devnet-wallet-2
	$(PRECMD)echo Successfully generated genesis
	$(call tagioncmd, tagiondartutil --dump --drt ./genesis/dart.drt)

devnet-genesis-dart: $(DDEVNET)/genesis/dart.drt
	@

devnet-wallet-%: | devnet-genesis-dart $(DDEVNET)/genesis/.w%-genesis
	@


$(DDEVNET)/genesis/dart.drt: $(DDEVNET)/genesis/.way
	$(PRECMD)$(call tagioncmd, tagiondartutil --initialize --drt ./genesis/dart.drt)

$(DDEVNET)/wallets/w%/tagionwallet.json: $(DDEVNET)/wallets/w%/.way
	$(PRECMD)$(call tagioncmd, cd ./wallets/w$*/ && tagionwallet -x $(DEVNET_PIN) --generate-wallet --questions $(DEVNET_QUESTIONS) --answers $(DEVNET_ANSWERS))
	
$(DDEVNET)/wallets/w%/invoice_file.hibon: $(DDEVNET)/wallets/w%/tagionwallet.json
	$(PRECMD)$(call tagioncmd, cd ./wallets/w$*/ && tagionwallet -x $(DEVNET_PIN) --create-invoice genesis:1000)

$(DDEVNET)/wallets/w%/dart.hibon: $(DDEVNET)/wallets/w%/invoice_file.hibon
	$(PRECMD)$(call tagioncmd, cd ./wallets/w$*/ && tagionboot invoice_file.hibon)

$(DDEVNET)/genesis/.w%-genesis: $(DDEVNET)/wallets/w%/dart.hibon
	$(PRECMD)$(call tagioncmd, tagiondartutil --drt ./genesis/dart.drt -m -i ./wallets/w$*/dart.hibon)