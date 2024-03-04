
TAUON_ROOT:=$(abspath $(DSRC)/wasi)
TAUON_TEST_ROOT:=$(abspath $(TAUON_ROOT)/tests)

TAUON_TESTS+=tauon_test.d

TAUON_DINC+=$(TAUON_ROOT)

TAUON_DINC+=$(DSRC)/lib-basic
TAUON_DINC+=$(DSRC)/lib-hibon
TAUON_DINC+=$(DSRC)/lib-phobos
TAUON_DINC+=$(DSRC)/lib-utils
TAUON_DINC+=$(DSRC)/lib-crypto
TAUON_DINC+=$(DSRC)/wasi

TAUON_DFILES+=$(DSRC)/wasi/tvm/wasi_main.d

TAUON_DFILES+=$(DSRC)/lib-basic/tagion/basic/basic.d
TAUON_DFILES+=$(DSRC)/lib-basic/tagion/basic/Message.d
TAUON_DFILES+=$(DSRC)/lib-basic/tagion/basic/Types.d
TAUON_DFILES+=$(DSRC)/lib-basic/tagion/basic/Version.d
TAUON_DFILES+=$(DSRC)/lib-basic/tagion/basic/tagionexceptions.d

TAUON_DFILES+=$(DSRC)/lib-utils/tagion/utils/LEB128.d

TAUON_DFILES+=$(DSRC)/lib-hibon/tagion/hibon/Document.d
TAUON_DFILES+=$(DSRC)/lib-hibon/tagion/hibon/HiBONRecord.d
TAUON_DFILES+=$(DSRC)/lib-hibon/tagion/hibon/HiBON.d
TAUON_DFILES+=$(DSRC)/lib-hibon/tagion/hibon/HiBONBase.d
TAUON_DFILES+=$(DSRC)/lib-hibon/tagion/hibon/HiBONException.d
TAUON_DFILES+=$(DSRC)/lib-hibon/tagion/hibon/HiBONJSON.d
TAUON_DFILES+=$(DSRC)/lib-hibon/tagion/hibon/HiBONtoText.d
TAUON_DFILES+=$(DSRC)/lib-hibon/tagion/hibon/BigNumber.d

TAUON_DFILES+=$(DSRC)/lib-crypto/tagion/crypto/aes/tiny_aes/tiny_aes.d 
TAUON_DFILES+=$(DSRC)/lib-crypto/tagion/crypto/aes/AESCrypto.d 
TAUON_DFILES+=$(DSRC)/lib-crypto/tagion/crypto/pbkdf2.d 
TAUON_DFILES+=$(DSRC)/lib-crypto/tagion/crypto/Types.d 
TAUON_DFILES+=$(DSRC)/lib-crypto/tagion/crypto/SecureInterfaceNet.d 
TAUON_DFILES+=$(DSRC)/lib-crypto/tagion/crypto/Cipher.d 
TAUON_DFILES+=$(DSRC)/lib-crypto/tagion/crypto/random/random.d 

#TAUON_DFILES+=$(DSRC)/lib-hibon/tagion/hibon/HiBON.d
#TAUON_DFILES+=$(DSRC)/lib-hibon/tagion/hibon/HiBON.d

#TAUON_DFILES+=$(DSRC)/lib-hibon/tagion/hibon/Version.d

