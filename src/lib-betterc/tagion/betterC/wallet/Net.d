module tagion.betterC.wallet.Net;

import tagion.crypto.aes.AESCrypto;
import tagion.betterC.utils.BinBuffer;
import std.format;
import std.string : representation;
private import tagion.crypto.secp256k1.c.secp256k1;
private import tagion.crypto.secp256k1.c.secp256k1_ecdh;
import tagion.betterC.utils.Memory;

// import tagion.betterC.hibon.Document;

enum HASH_SIZE = 32;
enum UNCOMPRESSED_PUBKEY_SIZE = 65;
enum COMPRESSED_PUBKEY_SIZE = 33;
enum SECKEY_SIZE = 32;

enum SECP256K1 : uint {
    FLAGS_TYPE_MASK = SECP256K1_FLAGS_TYPE_MASK,
    FLAGS_TYPE_CONTEXT = SECP256K1_FLAGS_TYPE_CONTEXT,
    FLAGS_TYPE_COMPRESSION = SECP256K1_FLAGS_TYPE_COMPRESSION,
    /** The higher bits contain the actual data. Do not use directly. */
    FLAGS_BIT_CONTEXT_VERIFY = SECP256K1_FLAGS_BIT_CONTEXT_VERIFY,
    FLAGS_BIT_CONTEXT_SIGN = SECP256K1_FLAGS_BIT_CONTEXT_SIGN,
    FLAGS_BIT_COMPRESSION = FLAGS_BIT_CONTEXT_SIGN,

    /** Flags to pass to secp256k1_context_create. */
    CONTEXT_VERIFY = SECP256K1_CONTEXT_VERIFY,
    CONTEXT_SIGN = SECP256K1_CONTEXT_SIGN,
    CONTEXT_NONE = SECP256K1_CONTEXT_NONE,

    /** Flag to pass to secp256k1_ec_pubkey_serialize and secp256k1_ec_privkey_export. */
    EC_COMPRESSED = SECP256K1_EC_COMPRESSED,
    EC_UNCOMPRESSED = SECP256K1_EC_UNCOMPRESSED,

    /** Prefix byte used to tag various encoded curvepoints for specific purposes */
    TAG_PUBKEY_EVEN = SECP256K1_TAG_PUBKEY_EVEN,
    TAG_PUBKEY_ODD = SECP256K1_TAG_PUBKEY_ODD,
    TAG_PUBKEY_UNCOMPRESSED = SECP256K1_TAG_PUBKEY_UNCOMPRESSED,
    TAG_PUBKEY_HYBRID_EVEN = SECP256K1_TAG_PUBKEY_HYBRID_EVEN,
    TAG_PUBKEY_HYBRID_ODD = SECP256K1_TAG_PUBKEY_HYBRID_ODD
}

void scramble(T)(scope ref T[] data, scope const(ubyte[]) xor = null) @safe if (T.sizeof is 1) {
    import std.random;

    auto gen = Mt19937(unpredictableSeed);
    foreach (ref s; data) { //, gen1, StoppingPolicy.shortest)) {
        s = gen.front & ubyte.max;
        gen.popFront;
    }
    foreach (i, x; xor) {
        data[i] ^= x;
    }
}

@trusted uint hashSize() pure nothrow {
    return HASH_SIZE;
}

@trusted immutable(BinBuffer) rawCalcHash(scope const(ubyte[]) data) {
    import std.digest.sha : SHA256;
    import std.digest;

    BinBuffer res;
    res.write(digest!SHA256(data));

    return cast(immutable)res;
}

@trusted immutable(ubyte[]) rawCalcHash(const BinBuffer buffer) {
    import std.digest.sha : SHA256;
    import std.digest;

    BinBuffer res;
    res.write(digest!SHA256(buffer.serialize));

    return res.serialize;
}

@trusted immutable(BinBuffer) calcHash(scope const(ubyte[]) data) {
    return rawCalcHash(data);
}

@trusted immutable(BinBuffer) calcHash(scope const(ubyte[]) h1, scope const(ubyte[]) h2)
// in {
//     assert(h1.length is 0 || h1.length is HASH_SIZE,
//             format("h1 is not a valid hash (length=%d should be 0 or %d", h1.length, HASH_SIZE));
//     assert(h2.length is 0 || h2.length is HASH_SIZE,
//             format("h2 is not a valid hash (length=%d should be 0 or %d", h2.length, HASH_SIZE));
// }
do {
    BinBuffer res;
    pragma(msg, "dlang: Pre and post condition does not work here");
    if (h1.length !is 0 && h2.length !is 0) {
        ubyte[] concatenat;
        concatenat.create(h1.length + h2.length);
        concatenat[0 .. h1.length] = h1;
        concatenat[h1.length .. $] = h2;
        return rawCalcHash(concatenat);
    }
    else if (h1.length is 0) {
        res.write(h2);
    }
    else if (h2.length is 0) {
        res.write(h1);
    }

    return cast(immutable)res;
}

@safe struct SecureNet {
    import tagion.basic.Basic : Pubkey;
    import std.digest.hmac : digestHMAC = HMAC;

    private Pubkey _pubkey;

    enum DER_SIGNATURE_SIZE = 72;
    enum SIGNATURE_SIZE = 64;
    private secp256k1_context* _ctx;

    enum Format {
        DER = 1,
        COMPACT = DER << 1,
        RAW = COMPACT << 1,
        AUTO = RAW | DER | COMPACT
    }

    private Format _format_verify;
    private Format _format_sign;

    @trusted
    immutable(ubyte[]) sign(const(ubyte[]) data, const(ubyte[]) sec) const
    in {
        assert(data.length == 32);
        assert(sec.length <= 32);
    }
    do {
        ubyte[] result;
        const msgdata = data.ptr;
        const secKey = sec.ptr;
        secp256k1_ecdsa_signature sig_array;
        secp256k1_ecdsa_signature* sig = &sig_array;

        int ret = secp256k1_ecdsa_sign(_ctx, sig, msgdata, secKey, null, null);
        if (_format_sign is Format.DER) {
            ubyte[DER_SIGNATURE_SIZE] outputSer_array;
            ubyte* outputSer = outputSer_array.ptr;
            size_t outputLen = outputSer_array.length;
            ret = secp256k1_ecdsa_signature_serialize_der(_ctx, outputSer, &outputLen, sig);
            if (ret) {
                result.create(outputLen);
                result[0.. $] = outputSer_array[0 .. outputLen];
                // immutable(ubyte[]) result = outputSer_array[0 .. outputLen].idup;
                return cast(immutable)result;
            }
        }
        if (_format_sign is Format.COMPACT) {
            ubyte[SIGNATURE_SIZE] outputSer_array;
            ubyte* outputSer = outputSer_array.ptr;
            //            size_t outputLen = outputSer_array.length;
            ret = secp256k1_ecdsa_signature_serialize_compact(_ctx, outputSer, sig);
            if (ret) {
                // immutable(ubyte[]) result = outputSer_array.idup;
                result.create(outputSer_array.length);
                result[0 .. $] = outputSer_array[0 .. $];
                return cast(immutable)result;
            }
        }
            //    writefln("Format=%s", _format_sign);
        result.create(SIGNATURE_SIZE);
        result[0 .. $] = sig.data[0 .. SIGNATURE_SIZE];
        // immutable(ubyte[]) result = sig.data[0 .. SIGNATURE_SIZE].idup;
        return cast(immutable)result;
    }

    @trusted
    void privKeyTweakMul(const(ubyte[]) privkey, const(ubyte[]) tweak, ref ubyte[] tweak_privkey) const
    in {
        assert(privkey.length == 32);
    }
    do {
        pragma(msg, "fixme(cbr): privkey must be scrambled");
        tweak_privkey[0 .. privkey.length] = privkey[0 .. $];
        ubyte* _privkey = tweak_privkey.ptr;
        const(ubyte)* _tweak = tweak.ptr;

        int ret = secp256k1_ec_privkey_tweak_mul(_ctx, _privkey, _tweak);
    }

    @trusted
    void privKeyTweakAdd(const(ubyte[]) privkey, const(ubyte[]) tweak, ref ubyte[] tweak_privkey) const
    in {
        assert(privkey.length == 32);
    }
    do {
        //        auto ctx=getContext();
        pragma(msg, "fixme(cbr): privkey must be scrambled");
        tweak_privkey[0 .. privkey.length] = privkey[0 .. $];
        ubyte* _privkey = tweak_privkey.ptr;
        const(ubyte)* _tweak = tweak.ptr;

        int ret = secp256k1_ec_privkey_tweak_add(_ctx, _privkey, _tweak);
    }

    @trusted
    immutable(ubyte[]) pubKeyTweakMul(const(ubyte[]) pubkey, const(ubyte[]) tweak, immutable bool compress = true) const {
        //        auto ctx=getContext();
        ubyte[] pubkey_array;
        pubkey_array.create(pubkey.length);
        pubkey_array[0 .. $] = pubkey[0 .. $];
        ubyte* _pubkey = pubkey_array.ptr;
        const(ubyte)* _tweak = tweak.ptr;
        size_t publen = pubkey.length;

        secp256k1_pubkey pubkey_result;
        int ret = secp256k1_ec_pubkey_parse(_ctx, &pubkey_result, _pubkey, publen);

        ret = secp256k1_ec_pubkey_tweak_mul(_ctx, &pubkey_result, _tweak);

        ubyte[] outputSer_array;
        SECP256K1 flag;
        if (compress) {
            outputSer_array.create(COMPRESSED_PUBKEY_SIZE);
            // outputSer_array = new ubyte[COMPRESSED_PUBKEY_SIZE];
            flag = SECP256K1.EC_COMPRESSED;
        }
        else {
            outputSer_array.create(UNCOMPRESSED_PUBKEY_SIZE);
            // outputSer_array = new ubyte[UNCOMPRESSED_PUBKEY_SIZE];
            flag = SECP256K1.EC_UNCOMPRESSED;
        }

        ubyte* outputSer = outputSer_array.ptr;
        size_t outputLen = outputSer_array.length;

        int ret2 = secp256k1_ec_pubkey_serialize(_ctx, outputSer, &outputLen, &pubkey_result, flag);

        return cast(immutable)(outputSer_array);
    }

    @trusted
    immutable(ubyte[]) computePubkey(scope const(ubyte[]) seckey, immutable bool compress = true) const
    in {
        assert(seckey.length == SECKEY_SIZE);
    }
    out (result) {
        if (compress) {
            assert(result.length == COMPRESSED_PUBKEY_SIZE);
        }
        else {
            assert(result.length == UNCOMPRESSED_PUBKEY_SIZE);
        }
    }
    do {
        //        auto ctx=getContext();
        const(ubyte)* sec = seckey.ptr;

        secp256k1_pubkey pubkey;

        int ret = secp256k1_ec_pubkey_create(_ctx, &pubkey, sec);
        // ubyte[pubkey_size] outputSer_array;
        ubyte[] outputSer_array;
        SECP256K1 flag;
        if (compress) {
            outputSer_array.create(COMPRESSED_PUBKEY_SIZE);
            // outputSer_array = new ubyte[COMPRESSED_PUBKEY_SIZE];
            flag = SECP256K1.EC_COMPRESSED;
        }
        else {
            outputSer_array.create(UNCOMPRESSED_PUBKEY_SIZE);
            // outputSer_array = new ubyte[UNCOMPRESSED_PUBKEY_SIZE];
            flag = SECP256K1.EC_UNCOMPRESSED;
        }
        ubyte* outputSer = outputSer_array.ptr;
        size_t outputLen = outputSer_array.length;

        int ret2 = secp256k1_ec_pubkey_serialize(_ctx, outputSer, &outputLen, &pubkey, flag);

        // immutable(ubyte[]) result = outputSer_array[0 .. outputLen].idup;
        ubyte[] result;
        result.create(outputLen);
        result[0 .. $] = outputSer_array[0 .. outputLen];
        return cast(immutable)result;
    }

    @trusted BinBuffer createECDHSecret(scope const(ubyte[]) seckey, const(
            ubyte[]) pubkey) const
    in {
        assert(seckey.length <= SECKEY_SIZE);
        assert(pubkey.length <= UNCOMPRESSED_PUBKEY_SIZE);
    }
    do {
        //        auto ctx=getContext();
        const secdata = seckey.ptr;
        const pubdata = pubkey.ptr;
        size_t publen = pubkey.length;

        secp256k1_pubkey pubkey_result;
        ubyte[] result;
        result.create(SECKEY_SIZE);
        ubyte* _result = result.ptr;

        int ret = secp256k1_ec_pubkey_parse(_ctx, &pubkey_result, pubdata, publen);

        //if (ret) {
        ret = secp256k1_ecdh(_ctx, _result, &pubkey_result, secdata, null, null);
        //}
        BinBuffer buf_res;
        buf_res.write(result);

        return buf_res;
    }

    @trusted bool secKeyVerify(scope const(ubyte[]) seckey) const
    in {
        assert(seckey.length == 32);
    }
    do {
        const(ubyte)* sec = seckey.ptr;
        return secp256k1_ec_seckey_verify(_ctx, sec) == 1;
    }

    struct AES {
        enum KEY_LENGTH = 256;
        enum KEY_SIZE = KEY_LENGTH / 8;
        enum BLOCK_SIZE = 16;

        static size_t enclength(const size_t inputlength) {
            return ((inputlength / BLOCK_SIZE) + ((inputlength % BLOCK_SIZE == 0) ? 0 : 1)) * BLOCK_SIZE;
        }
        import tagion.crypto.aes.tiny_aes.tiny_aes;

        alias T_AES = Tiny_AES!(KEY_LENGTH, Mode.CBC);

        static void crypt_parse(bool ENCRYPT = true)(const(ubyte[]) key, ubyte[BLOCK_SIZE] iv, ref ubyte[] data) {
            scope aes = T_AES(key[0 .. KEY_SIZE], iv);
            static if (ENCRYPT) {
                aes.encrypt(data);
            }
            else {
                aes.decrypt(data);
            }
        }

        static void crypt(bool ENCRYPT = true)(scope const(ubyte[]) key, scope const(ubyte[]) iv, scope const(ubyte[]) indata, ref ubyte[] outdata) {
            if (outdata is null) {
                outdata.create(indata.length);
            }
            outdata[0 .. $] = indata[0 .. $];
            size_t old_length;
            if (outdata.length % BLOCK_SIZE !is 0) {
                old_length = outdata.length;
                outdata.length = enclength(outdata.length);
            }
            scope (exit) {
                if (old_length) {
                    outdata.length = old_length;
                }
            }
            ubyte[BLOCK_SIZE] temp_iv = iv[0 .. BLOCK_SIZE];
            crypt_parse!ENCRYPT(key, temp_iv, outdata);
        }

        alias encrypt = crypt!true;
        alias decrypt = crypt!false;
    }

    @trusted void createKeyPair(ref ubyte[] privkey)
    in {
        assert(secKeyVerify(privkey));
    }
    do {
        import std.digest.sha : SHA256;
        import std.string : representation;

        _pubkey = computePubkey(privkey);
        // Generate scramble key for the private key
        import std.random;

        ubyte[] seed;
        seed.create(32);

        scramble(seed);
        // CBR: Note AES need to be change to beable to handle const keys
        auto aes_key = rawCalcHash(seed);
        scramble(seed);
        auto ase_pre_iv = rawCalcHash(seed);
        auto aes_iv = ase_pre_iv[4 .. 4 + AES.BLOCK_SIZE];

        // Encrypt private key
        // auto encrypted_privkey = new ubyte[privkey.length];
        ubyte[] encrypted_privkey;
        encrypted_privkey.create(privkey.length);
        AES.encrypt(aes_key.serialize, aes_iv.serialize, privkey, encrypted_privkey);

        AES.encrypt(rawCalcHash(seed).serialize, aes_iv.serialize, encrypted_privkey, privkey);
        scramble(seed);

        AES.encrypt(aes_key.serialize, aes_iv.serialize, encrypted_privkey, privkey);

        AES.encrypt(aes_key.serialize, aes_iv.serialize, privkey, seed);

        AES.encrypt(aes_key.serialize, aes_iv.serialize, encrypted_privkey, privkey);

        void do_secret_stuff(scope void delegate(const(ubyte[]) privkey) @safe dg) {
            // CBR:
            // Yes I know it is security by obscurity
            // But just don't want to have the private in clear text in memory
            // for long period of time
            // auto privkey = new ubyte[encrypted_privkey.length];

            ubyte[] privkey;
            privkey.create(encrypted_privkey);
            scope (exit) {
                ubyte[] seed;
                seed.create(32);
                scramble(seed, aes_key.serialize);
                // problems with immutable stuff - know how to fix, but need to rewrite prev then
                // scramble(aes_key.serialize, seed);
                // scramble(aes_iv.serialize);
                AES.encrypt(aes_key.serialize, aes_iv.serialize, privkey, encrypted_privkey);
                AES.encrypt(rawCalcHash(seed).serialize, aes_iv.serialize, encrypted_privkey, privkey);
            }
            AES.decrypt(aes_key.serialize, aes_iv.serialize, encrypted_privkey, privkey);
            dg(privkey);
        }

        void tweakMul(const(ubyte[]) tweak_code, ref ubyte[] tweak_privkey) {
            do_secret_stuff((const(ubyte[]) privkey) @safe { privKeyTweakMul(privkey, tweak_code, tweak_privkey); });
        }

        void tweakAdd(const(ubyte[]) tweak_code, ref ubyte[] tweak_privkey) {
            do_secret_stuff((const(ubyte[]) privkey) @safe { privKeyTweakAdd(privkey, tweak_code, tweak_privkey); });
        }

        immutable(ubyte[]) ECDHSecret(const(ubyte[]) pubkey) const {
            BinBuffer result;
            do_secret_stuff((const(ubyte[]) privkey) @trusted {
                result = createECDHSecret(privkey, pubkey);
            });
            return result.serialize;
        }

    }

    @trusted immutable(ubyte[]) HMAC(scope const(ubyte[]) data) const {
        import std.digest.sha : SHA256;
        import std.digest.hmac : digestHMAC = HMAC;

        scope hmac = digestHMAC!SHA256(data);
        auto res_size = hmac.finish.length;
        ubyte[] result;
        result.create(res_size);
        result[0 .. $] = hmac.finish[0 .. $];
        return cast(immutable)result;
    }

    Pubkey pubkey() pure const nothrow {
        return _pubkey;
    }

    Pubkey derivePubkey(string tweak_word) const {
        const tweak_code = HMAC(tweak_word.representation);
        return derivePubkey(tweak_code);
    }

    Pubkey derivePubkey(const(ubyte[]) tweak_code) const {
        Pubkey result;
        const pkey = cast(const(ubyte[])) _pubkey;
        result = pubKeyTweakMul(pkey, tweak_code);
        return result;
    }

}
