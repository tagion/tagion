module tagion.crypto.Cipher;

import std.exception : assumeUnique, ifThrown;
import tagion.basic.Types : Buffer;
import tagion.crypto.Types : Pubkey;
import tagion.crypto.random.random;
import tagion.hibon.Document;
import tagion.hibon.HiBONRecord;

@safe
struct Cipher {
    import tagion.crypto.secp256k1.NativeSecp256k1;
    import std.digest.crc : crc64ECMAOf;
    import tagion.basic.ConsensusExceptions : ConsensusException, ConsensusFailCode, SecurityConsensusException;
    import tagion.crypto.SecureInterfaceNet : SecureNet;
    import tagion.crypto.SecureNet : check;
    import tagion.crypto.random.random;
    import tagion.crypto.aes.AESCrypto : AESCrypto;

    alias AES = AESCrypto!256;
    enum CRC_SIZE = crc64ECMAOf.length;

    @recordType("TCD")
    struct CipherDocument {
        @label("$m") Buffer ciphermsg;
        @label("$n") Buffer nonce;
        @label("$a") Buffer authTag;
        @label("$k") Pubkey cipherPubkey;
        mixin HiBONRecord;
    }

    static const(CipherDocument) encrypt(const(SecureNet) net, const(Pubkey) pubkey, const(Document) msg) {

        scope ubyte[32] secret_key_alloc;
        scope ubyte[] secret_key = secret_key_alloc;
        scope (exit) {
            secret_key[] = 0;
        }
        getRandom(secret_key);
        CipherDocument result;
        result.cipherPubkey = net.getPubkey(secret_key);
        scope ubyte[AES.BLOCK_SIZE] nonce_alloc;
        scope ubyte[] nonce = nonce_alloc;
        getRandom(nonce);
        result.nonce = nonce.idup;
        // Appand CRC
        auto ciphermsg = new ubyte[AES.enclength(msg.data.length + CRC_SIZE)];

        // Put random padding to in the last block
        auto last_block = ciphermsg[$ - AES.BLOCK_SIZE + CRC_SIZE .. $];
        getRandom(last_block);
        const crc = msg.data.crc64ECMAOf;
        ciphermsg[0 .. msg.data.length] = msg.data;
        ciphermsg[msg.data.length .. msg.data.length + CRC_SIZE] = crc;

        scope sharedECCKey = net.ECDHSecret(secret_key, pubkey);
        AES.encrypt(sharedECCKey, result.nonce, ciphermsg, ciphermsg);
        Buffer get_ciphermsg() @trusted {
            return assumeUnique(ciphermsg);
        }

        result.ciphermsg = get_ciphermsg;
        return result;
    }

    static const(CipherDocument) encrypt(const(SecureNet) net, const(Document) msg) {
        return encrypt(net, net.pubkey, msg);
    }

    static const(Document) decrypt(const(SecureNet) net, const(CipherDocument) cipher_doc) {
        scope sharedECCKey = net.ECDHSecret(cipher_doc.cipherPubkey);
        auto clearmsg = new ubyte[cipher_doc.ciphermsg.length];
        AES.decrypt(sharedECCKey, cipher_doc.nonce, cipher_doc.ciphermsg, clearmsg);
        Buffer data = (() @trusted => assumeUnique(clearmsg))();
        const result = Document(data);
        immutable full_size = result.full_size;
        check(full_size + CRC_SIZE <= data.length && full_size !is 0,
                ConsensusFailCode.CIPHER_DECRYPT_ERROR);
        const crc = data[full_size .. full_size + CRC_SIZE];
        check(data[0 .. full_size].crc64ECMAOf == crc, 
                ConsensusFailCode.CIPHER_DECRYPT_CRC_ERROR);
        return result;
    }

    unittest {
        import std.algorithm.searching : all, any;
        import tagion.basic.Types : FileExtension;
        import tagion.basic.basic : fileId;
        import tagion.crypto.SecureNet;
        import tagion.hibon.Document : Document;
        import tagion.hibon.HiBON : HiBON;
        import tagion.utils.Miscellaneous : decode;

        immutable passphrase = "Secret pass word";
        auto net = new StdSecureNet; /// Only works with ECDSA for now 
        net.generateKeyPair(passphrase);

        immutable some_secret_message = "Text to be encrypted by ECC public key and " ~
            "decrypted by its corresponding ECC private key";
        auto hibon = new HiBON;
        hibon["text"] = some_secret_message;
        const secret_doc = Document(hibon);

        { // Encrypt and Decrypt secrte message
            auto dummy_net = new StdSecureNet;
            const secret_cipher_doc = Cipher.encrypt(dummy_net, net.pubkey, secret_doc);
            const encrypted_doc = Cipher.decrypt(net, secret_cipher_doc);
            assert(encrypted_doc["text"].get!string == some_secret_message);
            assert(secret_doc.data == encrypted_doc.data);
        }

        { // Use of the wrong privat-key
            auto dummy_net = new StdSecureNet;
            auto wrong_net = new StdSecureNet;
            immutable wrong_passphrase = "wrong word";
            wrong_net.generateKeyPair(wrong_passphrase);
            bool cipher_decrypt_error;
            bool cipher_decrypt_crc_error;
            while (!cipher_decrypt_error || !cipher_decrypt_crc_error) {
                const secret_cipher_doc = Cipher.encrypt(dummy_net, wrong_net.pubkey, secret_doc);
                try {
                    const encrypted_doc = Cipher.decrypt(net, secret_cipher_doc);
                    assert(secret_doc != encrypted_doc);
                    if (!encrypted_doc.empty) {
                        break; /// Run the loop until the decrypt does not fail
                    }
                }
                catch (ConsensusException e) {
                    cipher_decrypt_error |= (e.code == ConsensusFailCode.CIPHER_DECRYPT_ERROR);
                    cipher_decrypt_crc_error |= (e.code == ConsensusFailCode.CIPHER_DECRYPT_CRC_ERROR);
                }
            }
        }

        { // Encrypt and Decrypt secrte message with owner privat-key
            const secret_cipher_doc = Cipher.encrypt(net, secret_doc);
            const encrypted_doc = Cipher.decrypt(net, secret_cipher_doc);
            assert(encrypted_doc["text"].get!string == some_secret_message);
            assert(secret_doc.data == encrypted_doc.data);
        }

    }

}
