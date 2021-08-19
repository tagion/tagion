ifdef OPENSSL_AES
SOURCEFLAGS+=-not -path "*/tiny_aes/*"
ctx/lib/crypto: ctx/lib/hibon ctx/wrap/secp256k1 ctx/wrap/openssl
else
SOURCEFLAGS+=-not -path "*/openssl_aes/*"
DCFLAGS+=$(DVERSION)=TINY_AES
ctx/lib/crypto: ctx/lib/hibon ctx/wrap/secp256k1
endif
