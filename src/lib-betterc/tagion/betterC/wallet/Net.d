module tagion.betterC.wallet.Net;

// import tagion.crypto.aes.AESCrypto;
import std.format;
import std.string : representation;
import tagion.betterC.utils.BinBuffer;
private import tagion.crypto.secp256k1.c.secp256k1;
private import tagion.crypto.secp256k1.c.secp256k1_ecdh;
import tagion.betterC.utils.Memory;
import hash = tagion.betterC.wallet.hash;

// import tagion.betterC.hibon.Document;

enum HASH_SIZE = 32;
enum UNCOMPRESSED_PUBKEY_SIZE = 65;
enum COMPRESSED_PUBKEY_SIZE = 33;
enum SECKEY_SIZE = 32;

@trusted
void scramble(T)(scope ref T[] data, scope const(ubyte[]) xor = null) if (T.sizeof is 1) {
    // import std.random;
    ubyte[] seed;
    seed.create(data.length);

    randomize(cast(immutable) seed);
    foreach (i; data) {
        data[i] ^= seed[i];
    }
}

@trusted uint hashSize() pure nothrow {
    return HASH_SIZE;
}

@trusted BinBuffer rawCalcHash(scope const(ubyte[]) data) {
    BinBuffer res;
    res.write(hash.secp256k1_count_hash(data));

    return res;
}

@trusted immutable(ubyte[]) rawCalcHash(const BinBuffer buffer) {
    BinBuffer res;
    res.write(hash.secp256k1_count_hash(buffer.serialize));

    return res.serialize;
}

@trusted immutable(BinBuffer) calcHash(scope const(ubyte[]) data) {
    return cast(immutable) rawCalcHash(data);
}

@trusted immutable(BinBuffer) calcHash(scope const(ubyte[]) h1, scope const(ubyte[]) h2) {
    BinBuffer res;
    if (h1.length !is 0 && h2.length !is 0) {
        ubyte[] concatenat;
        concatenat.create(h1.length + h2.length);
        concatenat[0 .. h1.length] = h1;
        concatenat[h1.length .. $] = h2;
        return cast(immutable) rawCalcHash(concatenat);
    }
    else if (h1.length is 0) {
        res.write(h2);
    }
    else if (h2.length is 0) {
        res.write(h1);
    }

    return cast(immutable) res;
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

    static void crypt(bool ENCRYPT = true)(scope const(ubyte[]) key, scope const(ubyte[]) iv, scope const(
            ubyte[]) indata, ref ubyte[] outdata) {
        if (outdata is null) {
            outdata.create(indata.length);
        }
        outdata[0 .. $] = indata[0 .. $];
        size_t old_length;
        if (outdata.length % BLOCK_SIZE !is 0) {
            old_length = outdata.length;
            // outdata.length = enclength(outdata.length);
            outdata.create(enclength(outdata.length));
        }
        ubyte[BLOCK_SIZE] temp_iv = iv[0 .. BLOCK_SIZE];
        crypt_parse!ENCRYPT(key, temp_iv, outdata);
    }

    alias encrypt = crypt!true;
    alias decrypt = crypt!false;
}

struct SecureNet {
    import tagion.crypto.Types : Pubkey, Signature;

    private Pubkey _pubkey;
    //     // private SignDelegate _crypt;
    //     immutable(ubyte[]) delegate(const(ubyte[])) sign_dg;

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
                result[0 .. $] = outputSer_array[0 .. outputLen];
                // immutable(ubyte[]) result = outputSer_array[0 .. outputLen].idup;
                return cast(immutable) result;
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
                return cast(immutable) result;
            }
        }
        //    writefln("Format=%s", _format_sign);
        result.create(SIGNATURE_SIZE);
        result[0 .. $] = sig.data[0 .. SIGNATURE_SIZE];
        // immutable(ubyte[]) result = sig.data[0 .. SIGNATURE_SIZE].idup;
        return cast(immutable) result;
    }

    // Signature sign(const(ubyte[]) message) const
    // in {
    //     assert(message.length == 32);
    // }
    // do {
    // import std.traits;

    // assert(_secret !is null, format("Signature function has not been intialized. Use the %s function", fullyQualifiedName!generateKeyPair));

    // return Signature(sign_dg(message));
    // }

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
        return cast(immutable) result;
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

    @trusted void createKeyPair(ref ubyte[] privkey)
    in {
        assert(secKeyVerify(privkey));
    }
    do {
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
        // struct SignWrapper {
        @trusted
        immutable(ubyte[]) raw_sign(const(ubyte[]) data, const(ubyte[]) sec) const
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

            // int ret = secp256k1_ecdsa_sign(_ctx, sig, msgdata, secKey, null, null);
            // check(ret == 1, ConsensusFailCode.SECURITY_SIGN_FAULT);
            // if (_format_sign is Format.DER) {
            //     ubyte[DER_SIGNATURE_SIZE] outputSer_array;
            //     ubyte* outputSer = outputSer_array.ptr;
            //     size_t outputLen = outputSer_array.length;
            //     ret = secp256k1_ecdsa_signature_serialize_der(_ctx, outputSer, &outputLen, sig);
            //     if (ret) {
            //         immutable(ubyte[]) result = outputSer_array[0 .. outputLen].idup;
            //         return result;
            //     }
            // }
            // if (_format_sign is Format.COMPACT) {
            //     ubyte[SIGNATURE_SIZE] outputSer_array;
            //     ubyte* outputSer = outputSer_array.ptr;
            //     //            size_t outputLen = outputSer_array.length;
            //     ret = secp256k1_ecdsa_signature_serialize_compact(_ctx, outputSer, sig);
            //     if (ret) {
            //         immutable(ubyte[]) result = outputSer_array.idup;
            //         return result;
            //     }
            // }
            // //        writefln("Format=%s", _format_sign);
            // immutable(ubyte[]) result = sig.data[0 .. SIGNATURE_SIZE].idup;
            return cast(immutable) result;
        }

        @trusted immutable(ubyte[]) sign(const(ubyte[]) message) const {
            immutable(ubyte)[] result;
            do_secret_stuff((const(ubyte[]) privkey) { result = raw_sign(message, privkey); });
            return result;
        }
        // }
        // SignWrapper sign_wrapper;
        // sign_dg = &sign_wrapper.sign;

        void tweakMul(const(ubyte[]) tweak_code, ref ubyte[] tweak_privkey) {
            do_secret_stuff((const(ubyte[]) privkey) @safe { privKeyTweakMul(privkey, tweak_code, tweak_privkey); });
        }

        void tweakAdd(const(ubyte[]) tweak_code, ref ubyte[] tweak_privkey) {
            do_secret_stuff((const(ubyte[]) privkey) @safe { privKeyTweakAdd(privkey, tweak_code, tweak_privkey); });
        }

        immutable(ubyte[]) ECDHSecret(const(ubyte[]) pubkey) const {
            BinBuffer result;
            do_secret_stuff((const(ubyte[]) privkey) @trusted { result = createECDHSecret(privkey, pubkey); });
            return result.serialize;
        }
    }

    @trusted immutable(ubyte[]) HMAC(scope const(ubyte[]) data) const {

        scope hmac = hash.secp256k1_count_hmac_hash(data);
        auto res_size = hmac.length;
        ubyte[] result;
        result.create(res_size);
        result[0 .. $] = hmac[0 .. $];
        return cast(immutable) result;
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

    Pubkey derivePubkey(BinBuffer tweak_buf) const {
        Pubkey result;
        //     // ubyte[] tweak_arr;
        //     // tweak_arr.create(tweak_buf.length);
        //     // tweak_arr[0..$] = tweak_buf[0..$];
        //     // return derivePubkey(tweak_arr);
        return result;
    }

    @trusted
    bool verify(const(ubyte[]) data, const(ubyte[]) signature, const(ubyte[]) pub) const
    in {
        assert(data.length == 32);
        assert(signature.length <= 520);
        assert(pub.length <= 520);
    }
    do {
        int ret;
        const sigdata = signature.ptr;
        auto siglen = signature.length;
        const pubdata = pub.ptr;
        const msgdata = data.ptr;

        secp256k1_ecdsa_signature sig;
        secp256k1_pubkey pubkey;
        if (_format_verify & Format.DER) {
            ret = secp256k1_ecdsa_signature_parse_der(_ctx, &sig, sigdata, siglen);
        }
        if (ret) {
            goto PARSED;
        }
        if (_format_verify & Format.COMPACT) {
            ret = secp256k1_ecdsa_signature_parse_compact(_ctx, &sig, sigdata);
        }
        if (ret) {
            goto PARSED;
        }
        if ((_format_verify & Format.RAW) || (_format_verify == 0)) {
            import core.stdc.string : memcpy;

            memcpy(&(sig.data), sigdata, siglen);
        }
    PARSED:
        auto publen = pub.length;
        ret = secp256k1_ec_pubkey_parse(_ctx, &pubkey, pubdata, publen);

        ret = secp256k1_ecdsa_verify(_ctx, &sig, msgdata, &pubkey);
        return ret == 1;
    }

}
