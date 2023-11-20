module tagion.crypto.Cipher;

import std.exception : assumeUnique, ifThrown;
import tagion.basic.Types : Buffer;
import tagion.crypto.Types : Pubkey;
import tagion.crypto.random.random;
import tagion.hibon.Document;
import tagion.hibon.HiBONRecord;

//import std.stdio;
// import tagion.utils.Miscellaneous: toHexString, decode;
// import tagion.hibon.HiBONJSON;
@safe
struct Cipher {
    import tagion.crypto.secp256k1.NativeSecp256k1;
    import std.digest.crc : crc32Of;
    import tagion.basic.ConsensusExceptions : ConsensusException, ConsensusFailCode, SecurityConsensusException;
    import tagion.crypto.SecureInterfaceNet : SecureNet;
    import tagion.crypto.SecureNet : check;
    import tagion.crypto.random.random;
    import tagion.crypto.aes.AESCrypto : AESCrypto;

    alias AES = AESCrypto!256;
    enum CRC_SIZE = crc32Of.length;

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

        // writefln("msg.size = %d", msg.size);
        // Put random padding to in the last block
        auto last_block = ciphermsg[$ - AES.BLOCK_SIZE + CRC_SIZE .. $];
        getRandom(last_block);
        ciphermsg[0 .. msg.data.length] = msg.data;
        const crc = msg.data.crc32Of;
        ciphermsg[msg.data.length .. msg.data.length + CRC_SIZE] = crc;

        scope sharedECCKey = net.ECDHSecret(secret_key, pubkey);

        // writefln("sharedECCKey = %s", sharedECCKey.toHexString);
        // writefln("result.nonce = %d", result.nonce.length);
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
        // writefln("sharedECCKey = %s", sharedECCKey.toHexString);
        auto clearmsg = new ubyte[cipher_doc.ciphermsg.length];
        AES.decrypt(sharedECCKey, cipher_doc.nonce, cipher_doc.ciphermsg, clearmsg);
        // writefln("clearmsg = %s", cast(string)clearmsg);
        Buffer get_clearmsg() @trusted {
            return assumeUnique(clearmsg);
        }
        //        import LEB128 = tagion.utils.LEB128;
        immutable data = get_clearmsg;
        const result = Document(data);
        immutable full_size = result.full_size;
        //        writefln("full_size=%d data.length=%d", full_size, data.length);
        check(full_size + CRC_SIZE <= data.length && full_size !is 0, ConsensusFailCode
                .CIPHER_DECRYPT_ERROR);

        const crc = data[0 .. full_size].crc32Of;
        // writefln("crc calc   %s", crc);
        // writefln("crc result %s", data[full_size..full_size+CRC_SIZE]);

        check(data[0 .. full_size].crc32Of == crc, ConsensusFailCode.CIPHER_DECRYPT_CRC_ERROR);

        // writefln("data size %d",  LEB128.decode!uint(data).value);
        return result;
    }

    unittest {
        import std.algorithm.searching : all, any;
        import tagion.basic.Types : FileExtension;
        import tagion.basic.basic : fileId;
    import tagion.crypto.SecureNet;
        import tagion.hibon.Document : Document;
        import tagion.hibon.HiBON : HiBON;
        import tagion.utils.Miscellaneous : decode, toHexString;

        immutable passphrase = "Secret pass word";
        auto net = new StdSecureNet; /// Only works with ECDSA for now 
        net.generateKeyPair(passphrase);

        immutable some_secret_message = "Text to be encrypted by ECC public key and " ~
            "decrypted by its corresponding ECC private key";
        auto hibon = new HiBON;
        hibon["text"] = some_secret_message;
        const secret_doc = Document(hibon);

        { // Encrypt and Decrypt secrte message
            //            writeln("Good");
            auto dummy_net = new StdSecureNet;
            const secret_cipher_doc = Cipher.encrypt(dummy_net, net.pubkey, secret_doc);
            const encrypted_doc = Cipher.decrypt(net, secret_cipher_doc);
            assert(encrypted_doc["text"].get!string == some_secret_message);
            assert(secret_doc.data == encrypted_doc.data);
        }

        { // Use of the wrong privat-key
            //            writeln("Bad");
            auto dummy_net = new StdSecureNet;
            auto wrong_net = new StdSecureNet;
            immutable wrong_passphrase = "wrong word";
            wrong_net.generateKeyPair(wrong_passphrase);
            for (;;) {
                const secret_cipher_doc = Cipher.encrypt(dummy_net, wrong_net.pubkey, secret_doc);
                const encrypted_doc = Cipher.decrypt(net, secret_cipher_doc)
                    .ifThrown!ConsensusException(Document());
                assert(secret_doc != encrypted_doc);
                if (!encrypted_doc.empty) {
                    break; /// Run the loop until the decrypt does not fail
                }
            }
        }

        { // Encrypt and Decrypt secrte message with owner privat-key
            //            writeln("Good 2");
            const secret_cipher_doc = Cipher.encrypt(net, secret_doc);
            const encrypted_doc = Cipher.decrypt(net, secret_cipher_doc);
            assert(encrypted_doc["text"].get!string == some_secret_message);
            assert(secret_doc.data == encrypted_doc.data);
        }

    }

}
