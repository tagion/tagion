module tagion.crypto.Cipher;

import tagion.basic.Basic;
import tagion.hibon.HiBONRecord;
import tagion.hibon.Document;
import std.exception : assumeUnique;

//@
struct Cipher {
    import tagion.crypto.secp256k1.NativeSecp256k1;
    import tagion.crypto.SecureNet : scramble;
    import tagion.crypto.SecureInterfaceNet : SecureNet;
    import tagion.crypto.aes.AESCrypto : AESCrypto;
    alias AES = AESCrypto!256;
    const SecureNet net;
    @disable this();
    this(const(SecureNet) net) {
        this.net = net;
    }

    @RecordType("TCD")
    struct CipherDocument {
        @Label("$m") Buffer ciphermsg;
        @Label("$n") Buffer nonce;
        @Label("$a") Buffer authTag;
        @Label("$k") Pubkey cipherPubkey;
    }

    const(CipherDocument) encrypt(const(Document) msg) const {
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
        auto ciphermsg = new ubyte[msg.data.length];
        scope sharedECCKey = net.ECDHSecret(secret_key, result.cipherPubkey);

        AES.encrypt(sharedECCKey, result.nonce, msg.data, ciphermsg);
        Buffer get_ciphermsg() @trusted {
            return assumeUnique(ciphermsg);
        }
        result.ciphermsg = get_ciphermsg;
        // () @trusted {
        //     pragma(msg, typeof(assumeUnique(ciphermsg)));
        //     return assumeUnique(ciphermsg);
        // };
        return result;
    }

    const(Document) decrypt(const(CipherDocument) cipher_doc) {
//        scope sharedECCKey = net.ECDHSecret(secret_key, result.cipherPubkey);
        return Document();
    }

    unittest {
        import std.stdio;
        import tagion.utils.Miscellaneous: toHexString, decode;
        auto crypt = new NativeSecp256k1(NativeSecp256k1.Format.RAW, NativeSecp256k1.Format.RAW);
        const PrivKey = decode("039c28258a97c779c88212a0e37a74ec90898c63b60df60a7d05d0424f6f6780");
        const PublicKey = crypt.computePubkey(PrivKey, false);

        // Random
        const ciphertextPrivKey = decode("f2785178d20217ed89e982ddca6491ed21d598d8545db503f1dee5e09c747164");
        const ciphertextPublicKey = crypt.computePubkey(ciphertextPrivKey, false);

        const sharedECCKey = crypt.createECDHSecret(ciphertextPrivKey, PublicKey);
        const sharedECCKey_2 = crypt.createECDHSecret(PrivKey, ciphertextPublicKey);

        writefln("sharedECCKey   %s", sharedECCKey.toHexString);
        writefln("sharedECCKey_2 %s", sharedECCKey_2.toHexString);

//        const secretKey = crypt.createECDHSecret(ciphertextPrivKey, bobPublicKey);


    }
}
