ifdef OPENSSL_AES
SOURCEFLAGS+=-not -path "*/tiny_aes/*"
else
SOURCEFLAGS+=-not -path "*/openssl_aes/*"
DCFLAGS+=$(DVERSION)=TINY_AES
endif

ctx/lib/crypto: ctx/lib/hibon ctx/wrap/secp256k1