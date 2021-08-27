ifdef TINY_AES
SOURCE_FIND_EXCLUDE+="*/openssl_aes/*"
DCFLAGS+=$(DVERSION)=TINY_AES
else
SOURCE_FIND_EXCLUDE+="*/tiny_aes/*"
endif

crypto.ctx: hibon.o wrap-secp256k1
