module tagion.crypto.Cipher;

import tagion.basic.Basic;
import tagion.hibon.HiBONRecord;
import tagion.hibon.Document;
import std.exception : assumeUnique;

import tagion.utils.Miscellaneous: toHexString, decode;
import tagion.hibon.HiBONJSON;
//@
struct Cipher {
    import tagion.crypto.secp256k1.NativeSecp256k1;
    import tagion.crypto.SecureNet : scramble;
    import tagion.crypto.SecureInterfaceNet : SecureNet;
    import tagion.crypto.aes.AESCrypto : AESCrypto;
    alias AES = AESCrypto!256;
    // import std.stdio;
    // const SecureNet net;
    // @disable this();
    // this(const(SecureNet) net) {
    //     this.net = net;
    // }

    @RecordType("TCD")
    struct CipherDocument {
        @Label("$m") Buffer ciphermsg;
        @Label("$n") Buffer nonce;
        @Label("$a") Buffer authTag;
        @Label("$k") Pubkey cipherPubkey;
        mixin HiBONRecord;
    }

    static const(CipherDocument) encrypt(const(SecureNet) net, const(Pubkey) pubkey, const(Document) msg) {
        scope ubyte[32] secret_seed_alloc;
        scope ubyte[] secret_seed=secret_seed_alloc;
        scramble(secret_seed);
        scope secret_key = net.HMAC(secret_seed);
        scramble(secret_seed);
        CipherDocument result;
        result.cipherPubkey = net.computePubkey(secret_key);
        scope ubyte[AES.BLOCK_SIZE] nonce_alloc;
        scope ubyte[] nonce = nonce_alloc;
        scramble(nonce);
        result.nonce = nonce.idup;
        auto ciphermsg = new ubyte[AES.enclength(msg.data.length)];
        // writefln("msg.size = %d", msg.size);
        // Put random padding to in the last block
        auto last_block =ciphermsg[$-AES.BLOCK_SIZE..$];
        scramble(last_block);
        ciphermsg[0..msg.data.length] = msg.data;

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
        import LEB128 = tagion.utils.LEB128;
        immutable data = get_clearmsg;
        // writefln("data size %d",  LEB128.decode!uint(data).value);
        return Document(data);
    }

    unittest {
        import tagion.utils.Miscellaneous: toHexString, decode;
        import tagion.crypto.SecureNet : StdSecureNet;
        import tagion.hibon.HiBON : HiBON;
        import tagion.hibon.Document : Document;

        immutable passphrase = "Secret pass word";
        auto net = new StdSecureNet;
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

        { // You of the wrong privat-key
            auto dummy_net = new StdSecureNet;
            auto wrong_net = new StdSecureNet;
            immutable wrong_passphrase = "wrong word";
            wrong_net.generateKeyPair(wrong_passphrase);
            const secret_cipher_doc = Cipher.encrypt(dummy_net, wrong_net.pubkey, secret_doc);
            const encrypted_doc = Cipher.decrypt(net, secret_cipher_doc);
            assert(!encrypted_doc.isInorder);
            assert(encrypted_doc.full_size != secret_doc.full_size);
        }

        { // Encrypt and Decrypt secrte message with owner privat-key
            const secret_cipher_doc = Cipher.encrypt(net, secret_doc);
            const encrypted_doc = Cipher.decrypt(net, secret_cipher_doc);
            assert(encrypted_doc["text"].get!string == some_secret_message);
            assert(secret_doc.data == encrypted_doc.data);
        }

    }

}
