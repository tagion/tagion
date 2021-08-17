sources/core: add/lib/basic add/lib/utils add/lib/hibon add/lib/p2p add/lib/crypto add/lib/dart add/lib/funnel add/lib/gossip add/lib/hashgraph add/lib/network add/lib/services add/lib/wallet add/lib/wasm add/lib/communication add/lib/monitor add/bin/node
	@

sources/core: add/lib/basic add/lib/utils add/lib/hibon add/lib/p2p-go-wrapper
	@

blueprint/core: add/wrap/secp256k1 add/wrap/openssl add/wrap/p2p-go-wrapper sources/core env/dependencies
	$(PRECMD)meta git update
	$(PRECMD)meta git checkout alpha

blueprint/public: add/wrap/p2p-go-wrapper env/dependencies
	$(PRECMD)meta git update