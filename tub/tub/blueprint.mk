blueprint/core: meta/core add/wrap/secp256k1 add/wrap/openssl add/wrap/p2p-go-wrapper env/dependencies
	$(PRECMD)meta git update
	$(PRECMD)meta git checkout alpha

blueprint/public: meta/public add/wrap/p2p-go-wrapper env/dependencies
	$(PRECMD)meta git update