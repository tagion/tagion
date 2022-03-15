clean-devnet-nodes:
	$(PRECMD)rm -rf $(DDEVNET)/nodes

devnet-nodes: devnet-node-1 devnet-node-2 devnet-node-3 devnet-node-4 devnet-node-5
	$(PRECMD)echo Successfully created node directory structure

devnet-node-%: | devnet-genesis $(DDEVNET)/network/node-%/dart.drt
	$(PRECMD)echo Successfully created node $+ directory structure


$(DDEVNET)/network/node-%/dart.drt: $(DDEVNET)/network/node-%/.way
	$(PRECMD)cp $(DDEVNET)/genesis/dart.drt ${dir $@}