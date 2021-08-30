# 
# Source code cloning
# 
add/%: $(DIR_SRC)/%/context.mk
	@

$(DIR_SRC)/%/context.mk:
	$(PRECMD)git clone $(GIT_ORIGIN)/core-$(*) $(DIR_SRC)/$(*)	

add/core: add/lib-basic\
			  add/lib-utils\
			  add/lib-hibon\
			  add/lib-p2p-go-wrapper\
			  add/lib-crypto\
			  add/lib-dart\
			  add/lib-funnel\
			  add/lib-gossip\
			  add/lib-hashgraph\
			  add/lib-network\
			  add/lib-services\
			  add/lib-wallet\
			  add/lib-wasm\
			  add/lib-communication\
			  add/lib-monitor\
			  add/lib-logger\
			  add/lib-options\
			  add/bin-node\
			  add/bin-wasmutil\
			  add/wrap-secp256k1\
			  add/wrap-openssl\
			  add/wrap-p2p-go-wrapper
	@

add/public: add/lib-basic\
				add/lib-utils\
				add/lib-hibon\
				add/lib-p2p-go-wrapper\
				add/wrap-p2p-go-wrapper
	@