ifndef TINY_AES
SOURCEFLAGS+=-a -not -path "*/tiny_aes/*"
else
SOURCEFLAGS+=-a -not -path "*/openssl_aes/*"
DCFLAGS+=$(DVERSION)=TINY_AES
endif

ctx/lib/crypto: ctx/lib/hibon ctx/wrap/secp256k1