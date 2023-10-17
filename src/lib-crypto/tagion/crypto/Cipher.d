module tagion.crypto.Cipher;

import tagion.basic.Types : Buffer;
import tagion.crypto.Types : Pubkey;
import tagion.hibon.HiBONRecord;
import tagion.hibon.Document;
import std.exception : assumeUnique;

//import std.stdio;
// import tagion.utils.Miscellaneous: toHexString, decode;
// import tagion.hibon.HiBONJSON;
@safe
struct Cipher {
    import tagion.crypto.secp256k1.NativeSecp256k1;
    import tagion.crypto.SecureNet : scramble, check;
    import tagion.crypto.SecureInterfaceNet : SecureNet;
    import tagion.crypto.aes.AESCrypto : AESCrypto;
    import tagion.basic.ConsensusExceptions : ConsensusFailCode, SecurityConsensusException;
    import std.digest.crc : crc32Of;

    alias AES = AESCrypto!256;
    enum CRC_SIZE = crc32Of.length;

    // import std.stdio;
    // const SecureNet net;
    // @disable this();
    // this(const(SecureNet) net) {
    //     this.net = net;
    // }

    @recordType("TCD")
    struct CipherDocument {
        @label("$m") Buffer ciphermsg;
        @label("$n") Buffer nonce;
        @label("$a") Buffer authTag;
        @label("$k") Pubkey cipherPubkey;
        mixin HiBONRecord;
    }

    static const(CipherDocument) encrypt(const(SecureNet) net, const(Pubkey) pubkey, const(Document) msg) {

        //        immutable(ubyte[]) create_secret_key() {
        scope ubyte[32] secret_key_alloc;
        scope ubyte[] secret_key = secret_key_alloc;
        scope (exit) {
            scramble(secret_key);
        }
        do {
            scramble(secret_key);
            scramble(secret_key, net.HMAC(secret_key));
        }
        while (!net.secKeyVerify(secret_key));
        CipherDocument result;
        result.cipherPubkey = net.computePubkey(secret_key);
        scope ubyte[AES.BLOCK_SIZE] nonce_alloc;
        scope ubyte[] nonce = nonce_alloc;
        scramble(nonce);
        result.nonce = nonce.idup;
        // Appand CRC
        auto ciphermsg = new ubyte[AES.enclength(msg.data.length + CRC_SIZE)];

        // writefln("msg.size = %d", msg.size);
        // Put random padding to in the last block
        auto last_block = ciphermsg[$ - AES.BLOCK_SIZE + CRC_SIZE .. $];
        scramble(last_block);
        ciphermsg[0 .. msg.data.length] = msg.data;
        const crc = msg.data.crc32Of;
        //        writefln("crc %s", crc);
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
        import tagion.utils.Miscellaneous : toHexString, decode;
        import tagion.crypto.SecureNet : StdSecureNet;
        import tagion.hibon.HiBON : HiBON;
        import tagion.hibon.Document : Document;
        import tagion.basic.basic : fileId;
        import tagion.basic.Types : FileExtension;

        import std.algorithm.searching : all, any;

        immutable passphrase = "Secret pass word";
        auto net = new StdSecureNet;
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
            const secret_cipher_doc = Cipher.encrypt(dummy_net, wrong_net.pubkey, secret_doc);
            const encrypted_doc = Cipher.decrypt(net, secret_cipher_doc);
            //                writefln("encrypted_doc.full_size %d", encrypted_doc.full_size);
            assert(secret_doc != encrypted_doc);

            //            assert(passed);
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
