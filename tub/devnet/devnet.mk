include $(DTUB)/devnet/common.mk
include $(DTUB)/devnet/genesis.mk
include $(DTUB)/devnet/nodes.mk

clean-devnet: clean-devnet-wallets clean-devnet-genesis clean-devnet-nodes
	@

devnet-all: devnet-nodes
	@