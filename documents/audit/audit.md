
SL-1:
The reverse SBox are generated in pre-runtime this means it's only calculated once.

SL-2:
The crypt calls crypt_parse which calls the `real` AES function.
The diffence between crypt and crypt_parse is that crypt_parse overwrites the input data but crypt copies it if the input and out data does not overlap.

SL-3:
NativeSecp256k1 context constructor change to use SECP256K1_CONTEXT_NONE

SL-4:
NativeSecp256k1.createKeyPair reduced to one function

SL-5:
The sign function can not be called with a zero-length aux_random anymore.
If the aux_random is not specified then the aux_random is now generated internally.

SL-6:
Note. Accoring to secp256k1.h documentation for
secp256k1_context_create it is recommended to call secp256k1_context_randomize after calling
secp256k1_context_create.

secp256k1_context_randomize removed from createECDHSecret, pubTweak

secp256k1_context_randomize added to the cloneContext

SL-7:
privkey renamed to keypair (Fits the Schnorr implementation)

SL-8: 
BIP39 now support validateMnemonic

SL-9:
Checksum calculated with the deriveChecksumBits function and the last word of the mnemonic-sentences is generated from the checksum.
The checksum is also checked in the mnemonicToEntropy function.

SL-10:
checkMnemonicNumber has been removed

SL-11:
mnemonicNumbers is deprecated and should be removed when the dependencies has been removed.

SL-12:
entropy function calculates the raw entropies raw list of word-number.
This should not be used directly only to analyze problems.
mnemonicToEntropy should be used instead.

SL-13:
opCall is deprecated and should be updated when we have solved the dependencies.

SL-14:
NFKD normalisation been added to the salt inside the mnemonicToEntropy to normalise the mnemonic-sentence.

SL-15:
entropyToMnemonic has been added

SL-16:
generateMnemonic checkes that the number of words is a multiple of 3 and the entropy is between 16 and 32 bytes,
meanng from 12 to 24 words.
validateMnemonic has also been added.

SL-17 & SL-18: 
We havn't found a good solution of this yet.




