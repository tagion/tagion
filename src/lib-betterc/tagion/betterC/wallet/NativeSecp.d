module tagion.betterC.wallet.NativeSecp;

private import tagion.crypto.secp256k1.c.secp256k1;
private import tagion.crypto.secp256k1.c.secp256k1_ecdh;

import std.exception : assumeUnique;
import tagion.basic.ConsensusExceptions;

import tagion.utils.Miscellaneous : toHexString;
import tagion.betterC.utils.Memory;

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
};

struct NativeSecp256k1 {

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
    this(SECP256K1 flag) {
        flag = SECP256K1.CONTEXT_SIGN | SECP256K1.CONTEXT_VERIFY;
        _ctx = secp256k1_context_create(flag);
        _format_verify = Format.COMPACT;
        _format_sign = Format.COMPACT;
    }

    /++
     + Verifies the given secp256k1 signature in native code.
     + Calling when enabled == false is undefined (probably library not loaded)

     + Params:
     +       LREF data      = The data which was signed, must be exactly 32 bytes
     +       signature)     = The signature
     +       pub            =  The public key which did the signing
     +/
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

    /++
     + libsecp256k1 Create an ECDSA signature.
     +
     + @param data Message hash, 32 bytes
     + @param key Secret key, 32 bytes
     +
     + Return values
     + @param sig byte array of signature
     +/
    @trusted
    immutable(ubyte[]) sign(const(ubyte[]) data, const(ubyte[]) sec) const
    in {
        assert(data.length == 32);
        assert(sec.length <= 32);
    }
    do {
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
                // immutable(ubyte[]) result = outputSer_array[0 .. outputLen].idup;
                ubyte[] result;
                result.create(outputSer_array.dup.length);
                foreach (i, a; outputSer_array.dup) {
                    result[i] = a;
                }
                return cast(immutable) result;
            }
        }
        if (_format_sign is Format.COMPACT) {
            ubyte[SIGNATURE_SIZE] outputSer_array;
            ubyte* outputSer = outputSer_array.ptr;
            //            size_t outputLen = outputSer_array.length;
            ret = secp256k1_ecdsa_signature_serialize_compact(_ctx, outputSer, sig);
            if (ret) {
                //
                // immutable(ubyte[]) result = outputSer_array.idup;
                ubyte[] result;
                result.create(outputSer_array.dup.length);
                foreach (i, a; outputSer_array.dup) {
                    result[i] = a;
                }
                return cast(immutable) result;
            }
        }
        //        writefln("Format=%s", _format_sign);
        // immutable(ubyte[]) result = sig.data[0 .. SIGNATURE_SIZE].idup;

        ubyte[] result;
        result.create(SIGNATURE_SIZE);
        foreach (i, a; sig.data.dup) {
            result[i] = a;
        }
        return cast(immutable) result;
    }

    /++
     + libsecp256k1 Seckey Verify - returns true if valid, false if invalid
     +
     + @param seckey ECDSA Secret key, 32 bytes
     +/
    @trusted
    bool secKeyVerify(scope const(ubyte[]) seckey) const
    in {
        assert(seckey.length == 32);
    }
    do {
        const(ubyte)* sec = seckey.ptr;
        return secp256k1_ec_seckey_verify(_ctx, sec) == 1;
    }

    /++
     + libsecp256k1 Compute Pubkey - computes public key from secret key
     +
     + @param seckey ECDSA Secret key, 32 bytes
     +
     + Return values
     + @param pubkey ECDSA Public key, 33 or 65 bytes
     +/
    //TODO add a 'compressed' arg
    enum UNCOMPRESSED_PUBKEY_SIZE = 65;
    enum COMPRESSED_PUBKEY_SIZE = 33;
    enum SECKEY_SIZE = 32;
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
            flag = SECP256K1.EC_COMPRESSED;
        }
        else {
            outputSer_array.create(UNCOMPRESSED_PUBKEY_SIZE);
            flag = SECP256K1.EC_UNCOMPRESSED;
        }
        ubyte* outputSer = outputSer_array.ptr;
        size_t outputLen = outputSer_array.length;

        int ret2 = secp256k1_ec_pubkey_serialize(_ctx, outputSer, &outputLen, &pubkey, flag);

        //
        // immutable(ubyte[outputLen]) result = outputSer_array[0 .. outputLen].idup;
        ubyte[] result;
        result.create(outputSer_array.dup.length);
        foreach (i, a; outputSer_array.dup) {
            result[i] = a;
        }
        return cast(immutable) result;
    }

    /++
     + libsecp256k1 Cleanup - This destroys the secp256k1 context object
     + This should be called at the end of the program for proper cleanup of the context.
     +/
    @trusted ~this() {
        secp256k1_context_destroy(_ctx);
    }

    @trusted
    secp256k1_context* cloneContext() {
        return secp256k1_context_clone(_ctx);
    }

    /++
     + libsecp256k1 PrivKey Tweak-Mul - Tweak privkey by multiplying to it
     +
     + @param tweak some bytes to tweak with
     + @param seckey 32-byte seckey
     +/
    @trusted
    void privKeyTweakMul(const(ubyte[]) privkey, const(ubyte[]) tweak, ref ubyte[] tweak_privkey) const
    in {
        assert(privkey.length == 32);
    }
    do {
        pragma(msg, "fixme(cbr): privkey must be scrambled");
        tweak_privkey = privkey.dup;
        ubyte* _privkey = tweak_privkey.ptr;
        const(ubyte)* _tweak = tweak.ptr;

        int ret = secp256k1_ec_privkey_tweak_mul(_ctx, _privkey, _tweak);

    }

    /++
     + libsecp256k1 PrivKey Tweak-Add - Tweak privkey by adding to it
     +
     + @param tweak some bytes to tweak with
     + @param seckey 32-byte seckey
     +/
    @trusted
    void privKeyTweakAdd(const(ubyte[]) privkey, const(ubyte[]) tweak, ref ubyte[] tweak_privkey) const
    in {
        assert(privkey.length == 32);
    }
    do {
        //        auto ctx=getContext();
        pragma(msg, "fixme(cbr): privkey must be scrambled");
        tweak_privkey = privkey.dup;
        ubyte* _privkey = tweak_privkey.ptr;
        const(ubyte)* _tweak = tweak.ptr;

        int ret = secp256k1_ec_privkey_tweak_add(_ctx, _privkey, _tweak);
    }

    /++
     + libsecp256k1 PubKey Tweak-Add - Tweak pubkey by adding to it
     +
     + @param tweak some bytes to tweak with
     + @param pubkey 32-byte seckey
     +/
    @trusted
    immutable(ubyte[]) pubKeyTweakAdd(const(ubyte[]) pubkey, const(ubyte[]) tweak, immutable bool compress = true) const {
        //        auto ctx=getContext();
        ubyte[] pubkey_array;
        pubkey_array.create(pubkey.dup.length);
        foreach (i, a; pubkey.dup) {
            pubkey_array[i] = a;
        }
        ubyte* _pubkey = pubkey_array.ptr;
        const(ubyte)* _tweak = tweak.ptr;
        size_t publen = pubkey.length;

        secp256k1_pubkey pubkey_result;
        int ret = secp256k1_ec_pubkey_parse(_ctx, &pubkey_result, _pubkey, publen);

        ret = secp256k1_ec_pubkey_tweak_add(_ctx, &pubkey_result, _tweak);

        ubyte[] outputSer_array;
        SECP256K1 flag;
        if (compress) {
            outputSer_array.create(COMPRESSED_PUBKEY_SIZE);
            flag = SECP256K1.EC_COMPRESSED;
        }
        else {
            outputSer_array.create(UNCOMPRESSED_PUBKEY_SIZE);
            flag = SECP256K1.EC_UNCOMPRESSED;
        }

        ubyte* outputSer = outputSer_array.ptr;
        size_t outputLen = outputSer_array.length;

        int ret2 = secp256k1_ec_pubkey_serialize(_ctx, outputSer, &outputLen, &pubkey_result, flag);

        return assumeUnique(outputSer_array);
    }

    /++
     + libsecp256k1 PubKey Tweak-Mul - Tweak pubkey by multiplying to it
     +
     + @param tweak some bytes to tweak with
     + @param pubkey 32-byte seckey
     +/
    @trusted
    immutable(ubyte[]) pubKeyTweakMul(const(ubyte[]) pubkey, const(ubyte[]) tweak, immutable bool compress = true) const
    in {
        assert(pubkey.length == COMPRESSED_PUBKEY_SIZE || pubkey.length == UNCOMPRESSED_PUBKEY_SIZE);
    }
    do {
        //        auto ctx=getContext();
        ubyte[] pubkey_array;
        pubkey_array.create(pubkey.dup.length);
        foreach (i, a; pubkey.dup) {
            pubkey_array[i] = a;
        }
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
            flag = SECP256K1.EC_COMPRESSED;
        }
        else {
            outputSer_array.create(UNCOMPRESSED_PUBKEY_SIZE);
            flag = SECP256K1.EC_UNCOMPRESSED;
        }

        ubyte* outputSer = outputSer_array.ptr;
        size_t outputLen = outputSer_array.length;

        int ret2 = secp256k1_ec_pubkey_serialize(_ctx, outputSer, &outputLen, &pubkey_result, flag);

        return assumeUnique(outputSer_array);
    }

    /++
     + libsecp256k1 create ECDH secret - constant time ECDH calculation
     +
     + @param seckey byte array of secret key used in exponentiaion
     + @param pubkey byte array of public key used in exponentiaion
     +/
    @trusted immutable(ubyte[]) createECDHSecret(scope const(ubyte[]) seckey, const(
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
        ubyte[32] result;
        ubyte* _result = result.ptr;

        int ret = secp256k1_ec_pubkey_parse(_ctx, &pubkey_result, pubdata, publen);

        //if (ret) {
        ret = secp256k1_ecdh(_ctx, _result, &pubkey_result, secdata, null, null);
        //}

        return result.idup;
    }

    /++
     + libsecp256k1 randomize - updates the context randomization
     +
     + @param seed 32-byte random seed
     +/
    @trusted
    bool randomize(immutable(ubyte[]) seed)
    in {
        assert(seed.length == 32 || seed is null);
    }
    do {
        //        auto ctx=getContext();
        immutable(ubyte)* _seed = seed.ptr;
        return secp256k1_context_randomize(_ctx, _seed) == 1;
    }

}
