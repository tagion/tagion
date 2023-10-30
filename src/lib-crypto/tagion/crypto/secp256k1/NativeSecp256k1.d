module tagion.crypto.secp256k1.NativeSecp256k1;

/++
 + Copyright 2013 Google Inc.
 + Copyright 2014-2016 the libsecp256k1 contributors
 +
 + Licensed under the Apache License, Version 2.0 (the "License");
 + you may not use this file except in compliance with the License.
 + You may obtain a copy of the License at
 +
 +    http://www.apache.org/licenses/LICENSE-2.0
 +
 + Unless required by applicable law or agreed to in writing, software
 + distributed under the License is distributed on an "AS IS" BASIS,
 + WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 + See the License for the specific language governing permissions and
 + limitations under the License.
 +/
@safe:
private import tagion.crypto.secp256k1.c.secp256k1;
private import tagion.crypto.secp256k1.c.secp256k1_ecdh;
private import tagion.crypto.secp256k1.c.secp256k1_hash;
private import tagion.crypto.secp256k1.c.secp256k1_schnorrsig;
private import tagion.crypto.secp256k1.c.secp256k1_extrakeys;

import std.exception : assumeUnique;
import tagion.basic.ConsensusExceptions;

import tagion.utils.Miscellaneous : toHexString;
import std.algorithm;
import std.array;

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

/++
 + <p>This class holds native methods to handle ECDSA verification.</p>
 +
 + <p>You can find an example library that can be used for this at https://github.com/bitcoin/secp256k1</p>
 +
 + <p>To build secp256k1 for use with bitcoinj, run
 + `./configure --enable-jni --enable-experimental --enable-module-ecdh`
 + and `make` then copy `.libs/libsecp256k1.so` to your system library path
 + or point the JVM to the folder containing it with -Djava.library.path
 + </p>
 +/
class NativeSecp256k1 {
    static void check(bool flag, ConsensusFailCode code, string file = __FILE__, size_t line = __LINE__) pure {
        if (!flag) {
            throw new SecurityConsensusException(code, file, line);
        }
    }

    enum DER_SIGNATURE_SIZE = 72;
    enum SIGNATURE_SIZE = 64;

    package secp256k1_context* _ctx;

    enum Format {
        DER = 1,
        COMPACT = DER << 1,
        RAW = COMPACT << 1,
        AUTO = RAW | DER | COMPACT
    }

    private Format _format_verify;
    private Format _format_sign;
    @trusted
    this(const Format format_verify = Format.COMPACT,
            const Format format_sign = Format.COMPACT,
            const SECP256K1 flag = SECP256K1.CONTEXT_SIGN | SECP256K1.CONTEXT_VERIFY) nothrow
    in {
        with (Format) {
            assert((format_sign is DER) || (format_sign is COMPACT) || (format_sign is RAW),
                    "Only one format allowed to be specified for the singning (format_sign)");
        }
    }
    do {
        _ctx = secp256k1_context_create(flag);
        scope (exit) {
            randomizeContext;
        }
        _format_verify = format_verify;
        _format_sign = format_sign;
    }

    /++
     + Verifies the given secp256k1 signature in native code.
     + Calling when enabled == false is undefined (probably library not loaded)

     + Params:
     +       LREF data      = The data which was signed, must be exactly 32 bytes
     +       signature)     = The signature
     +       pub            =  The public key which did the signing
     +/
    alias verify = verify_ecdsa;
    @trusted
    bool verify_ecdsa(const(ubyte[]) data, const(ubyte[]) signature, const(ubyte[]) pub) const
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
        else {
            check((_format_verify & (Format.COMPACT | Format.RAW)) != 0, ConsensusFailCode
                    .SECURITY_DER_SIGNATURE_PARSE_FAULT);
        }
        if (_format_verify & Format.COMPACT) {
            ret = secp256k1_ecdsa_signature_parse_compact(_ctx, &sig, sigdata);
        }
        if (ret) {
            goto PARSED;
        }
        else {
            check((_format_verify & Format.RAW) || (_format_verify == 0), ConsensusFailCode
                    .SECURITY_COMPACT_SIGNATURE_PARSE_FAULT);
        }
        if ((_format_verify & Format.RAW) || (_format_verify == 0)) {
            check(siglen == SIGNATURE_SIZE, ConsensusFailCode.SECURITY_SIGNATURE_SIZE_FAULT);
            import core.stdc.string : memcpy;

            memcpy(&(sig.data), sigdata, siglen);
        }
    PARSED:
        auto publen = pub.length;
        ret = secp256k1_ec_pubkey_parse(_ctx, &pubkey, pubdata, publen);
        check(ret == 1, ConsensusFailCode.SECURITY_PUBLIC_KEY_PARSE_FAULT);

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
    alias sign = sign_ecdsa;
    @trusted
    immutable(ubyte[]) sign_ecdsa(const(ubyte[]) data, const(ubyte[]) sec) const
    in {
        assert(data.length == 32);
        assert(sec.length <= 32);
    }
    do {
        const msgdata = data.ptr;
        const secKey = sec.ptr;
        secp256k1_ecdsa_signature sig_array;
        secp256k1_ecdsa_signature* sig = &sig_array;
        scope (exit) {
            randomizeContext;

        }

        int ret = secp256k1_ecdsa_sign(_ctx, sig, msgdata, secKey, null, null);
        check(ret == 1, ConsensusFailCode.SECURITY_SIGN_FAULT);
        if (_format_sign is Format.DER) {
            ubyte[DER_SIGNATURE_SIZE] outputSer_array;
            ubyte* outputSer = outputSer_array.ptr;
            size_t outputLen = outputSer_array.length;
            ret = secp256k1_ecdsa_signature_serialize_der(_ctx, outputSer, &outputLen, sig);
            if (ret) {
                immutable(ubyte[]) result = outputSer_array[0 .. outputLen].idup;
                return result;
            }
        }
        if (_format_sign is Format.COMPACT) {
            ubyte[SIGNATURE_SIZE] outputSer_array;
            ubyte* outputSer = outputSer_array.ptr;
            //            size_t outputLen = outputSer_array.length;
            ret = secp256k1_ecdsa_signature_serialize_compact(_ctx, outputSer, sig);
            if (ret) {
                immutable(ubyte[]) result = outputSer_array.idup;
                return result;
            }
        }
        //        writefln("Format=%s", _format_sign);
        immutable(ubyte[]) result = sig.data[0 .. SIGNATURE_SIZE].idup;
        return result;
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
        check(ret == 1, ConsensusFailCode.SECURITY_PUBLIC_KEY_CREATE_FAULT);
        // ubyte[pubkey_size] outputSer_array;
        ubyte[] outputSer_array;
        SECP256K1 flag;
        if (compress) {
            outputSer_array = new ubyte[COMPRESSED_PUBKEY_SIZE];
            flag = SECP256K1.EC_COMPRESSED;
        }
        else {
            outputSer_array = new ubyte[UNCOMPRESSED_PUBKEY_SIZE];
            flag = SECP256K1.EC_UNCOMPRESSED;
        }
        ubyte* outputSer = outputSer_array.ptr;
        size_t outputLen = outputSer_array.length;

        int ret2 = secp256k1_ec_pubkey_serialize(_ctx, outputSer, &outputLen, &pubkey, flag);

        immutable(ubyte[]) result = outputSer_array[0 .. outputLen].idup;
        return result;
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
        check(ret == 1, ConsensusFailCode.SECURITY_PRIVATE_KEY_TWEAK_MULT_FAULT);

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
        pragma(msg, "fixme(cbr): privkey must be scrambled");
        tweak_privkey = privkey.dup;
        ubyte* _privkey = tweak_privkey.ptr;
        const(ubyte)* _tweak = tweak.ptr;

        int ret = secp256k1_ec_privkey_tweak_add(_ctx, _privkey, _tweak);
        check(ret == 1, ConsensusFailCode.SECURITY_PRIVATE_KEY_TWEAK_ADD_FAULT);
    }

    /++
     + libsecp256k1 PubKey Tweak-Add - Tweak pubkey by adding to it
     +
     + @param tweak some bytes to tweak with
     + @param pubkey 32-byte seckey
     +/
    @trusted
    immutable(ubyte[]) pubKeyTweakAdd(const(ubyte[]) pubkey, const(ubyte[]) tweak, immutable bool compress = true) const {
        if (compress) {
            check(pubkey.length == COMPRESSED_PUBKEY_SIZE, ConsensusFailCode
                    .SECURITY_PUBLIC_KEY_COMPRESS_SIZE_FAULT);
        }
        else {
            check(pubkey.length == UNCOMPRESSED_PUBKEY_SIZE, ConsensusFailCode
                    .SECURITY_PUBLIC_KEY_UNCOMPRESS_SIZE_FAULT);
        }
        //        auto ctx=getContext();
        ubyte[] pubkey_array = pubkey.dup;
        ubyte* _pubkey = pubkey_array.ptr;
        const(ubyte)* _tweak = tweak.ptr;
        size_t publen = pubkey.length;

        secp256k1_pubkey pubkey_result;
        int ret = secp256k1_ec_pubkey_parse(_ctx, &pubkey_result, _pubkey, publen);
        check(ret == 1, ConsensusFailCode.SECURITY_PUBLIC_KEY_PARSE_FAULT);

        ret = secp256k1_ec_pubkey_tweak_add(_ctx, &pubkey_result, _tweak);
        check(ret == 1, ConsensusFailCode.SECURITY_PUBLIC_KEY_TWEAK_ADD_FAULT);

        ubyte[] outputSer_array;
        SECP256K1 flag;
        if (compress) {
            outputSer_array = new ubyte[COMPRESSED_PUBKEY_SIZE];
            flag = SECP256K1.EC_COMPRESSED;
        }
        else {
            outputSer_array = new ubyte[UNCOMPRESSED_PUBKEY_SIZE];
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
        ubyte[] pubkey_array = pubkey.dup;
        ubyte* _pubkey = pubkey_array.ptr;
        const(ubyte)* _tweak = tweak.ptr;
        size_t publen = pubkey.length;

        secp256k1_pubkey pubkey_result;
        int ret = secp256k1_ec_pubkey_parse(_ctx, &pubkey_result, _pubkey, publen);
        check(ret == 1, ConsensusFailCode.SECURITY_PUBLIC_KEY_PARSE_FAULT);

        ret = secp256k1_ec_pubkey_tweak_mul(_ctx, &pubkey_result, _tweak);
        check(ret == 1, ConsensusFailCode.SECURITY_PUBLIC_KEY_TWEAK_MULT_FAULT);

        ubyte[] outputSer_array;
        SECP256K1 flag;
        if (compress) {
            outputSer_array = new ubyte[COMPRESSED_PUBKEY_SIZE];
            flag = SECP256K1.EC_COMPRESSED;
        }
        else {
            outputSer_array = new ubyte[UNCOMPRESSED_PUBKEY_SIZE];
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
        ubyte* _result = &result[0];

        int ret = secp256k1_ec_pubkey_parse(_ctx, &pubkey_result, pubdata, publen);
        check(ret == 1, ConsensusFailCode.SECURITY_PUBLIC_KEY_PARSE_FAULT);

        ret = secp256k1_ecdh(_ctx, _result, &pubkey_result, secdata, null, null);
        scope (exit) {
            randomizeContext;
        }
        check(ret == 1, ConsensusFailCode.SECURITY_EDCH_FAULT);

        return result.idup;
    }

    /++
     + libsecp256k1 randomize - updates the context randomization
     +
     + @param seed 32-byte random seed
     +/
    @trusted
    bool randomizeContext() nothrow const {
        import tagion.crypto.random.random;

        ubyte[] ctx_randomize;
        ctx_randomize.length = 32;
        getRandom(ctx_randomize);
        auto __ctx = cast(secp256k1_context*) _ctx;
        return secp256k1_context_randomize(__ctx, &ctx_randomize[0]) == 1;
    }

    enum XONLY_PUBKEY_SIZE = 32;
    enum MSG_SIZE = 32;
    enum KEYPAIR_SIZE = secp256k1_keypair.sizeof;
    @trusted
    void createKeyPair(const(ubyte[]) seckey, ref secp256k1_keypair keypair) const
    in (seckey.length == SECKEY_SIZE)
    do {
        //auto _keypair = new secp256k1_keypair;
        scope (exit) {
            //  keypair = _keypair.data[];
            randomizeContext;
        }
        const rt = secp256k1_keypair_create(_ctx, &keypair, &seckey[0]);
        check(rt == 1, ConsensusFailCode.SECURITY_FAILD_TO_CREATE_KEYPAIR);

    }

    @trusted
    void getSecretKey(ref scope const(ubyte[]) keypair, out ubyte[] seckey) nothrow
    in (keypair.length == secp256k1_keypair.data.length)
    do {
        seckey.length = SECKEY_SIZE;
        const _keypair = cast(secp256k1_keypair*)&keypair[0];
        const ret = secp256k1_keypair_sec(_ctx, &seckey[0], _keypair);
        assert(ret is 1);
    }

    @trusted
    void getPubkey(ref scope const(secp256k1_keypair) keypair, ref scope secp256k1_pubkey pubkey) const
    
    do {
        secp256k1_keypair_pub(_ctx, &pubkey, &keypair);
    }

    @trusted
    immutable(ubyte[]) sign_schnorr(
            const(ubyte[]) msg,
    ref scope const(secp256k1_keypair) keypair,
    const(ubyte[]) aux_random) const
    in (msg.length == MSG_SIZE)
    in (aux_random.length == MSG_SIZE)
    do {
        scope (exit) {
            randomizeContext;
        }
        auto signature = new ubyte[SIGNATURE_SIZE];
        const rt = secp256k1_schnorrsig_sign32(_ctx, &signature[0], &msg[0], &keypair, &aux_random[0]);
        check(rt == 1, ConsensusFailCode.SECURITY_FAILD_TO_SIGN_MESSAGE);
        return assumeUnique(signature);
    }

    @trusted
    bool verify_schnorr(const(ubyte[]) signature, const(ubyte[]) msg, const(ubyte[]) pubkey) const nothrow
    in (signature.length == SIGNATURE_SIZE)
    in (msg.length == MSG_SIZE)
    in (pubkey.length == XONLY_PUBKEY_SIZE)
    do {
        secp256k1_xonly_pubkey xonly_pubkey;
        secp256k1_xonly_pubkey_parse(_ctx, &xonly_pubkey, &pubkey[0]);

        const rt = secp256k1_schnorrsig_verify(_ctx, &signature[0], &msg[0], 32, &xonly_pubkey);
        return (rt == 1);
    }

    @trusted
    immutable(ubyte[]) xonly_pubkey(ref scope const(secp256k1_keypair) keypair) const {
        secp256k1_xonly_pubkey xonly_pubkey;
        {
            const rt = secp256k1_keypair_xonly_pub(_ctx, &xonly_pubkey, null, &keypair);
            check(rt == 1, ConsensusFailCode.SECURITY_FAILD_PUBKEY_FROM_KEYPAIR);
        }
        auto pubkey = new ubyte[XONLY_PUBKEY_SIZE];
        {
            const rt = secp256k1_xonly_pubkey_serialize(_ctx, &pubkey[0], &xonly_pubkey);
            check(rt == 1, ConsensusFailCode.SECURITY_FAILD_PUBKEY_FROM_KEYPAIR);
        }
        return assumeUnique(pubkey);

    }

    @trusted
    const(secp256k1_pubkey*) xonly_pubkey_tweak(
            scope const(ubyte[]) internal_pubkey,
    scope const(ubyte[]) tweak) const
    in (internal_pubkey.length == XONLY_PUBKEY_SIZE)
    in (tweak.length == 32)
    do {
        import std.stdio;

        secp256k1_xonly_pubkey xonly_pubkey;
        secp256k1_xonly_pubkey_parse(_ctx, &xonly_pubkey, &internal_pubkey[0]);

        auto output_pubkey = new secp256k1_pubkey;
        const rt = secp256k1_xonly_pubkey_tweak_add(_ctx, output_pubkey, &xonly_pubkey, &tweak[0]);
        return output_pubkey;
    }

    @trusted
    const(secp256k1_xonly_pubkey*) xonly_from_pubkey(
            const(secp256k1_pubkey*) pubkey,
            int* pk_parity = null) const {
        auto xonly_pubkey = new secp256k1_xonly_pubkey;
        const ret = secp256k1_xonly_pubkey_from_pubkey(_ctx, xonly_pubkey, pk_parity, pubkey);
        return xonly_pubkey;
    }

    @trusted
    const(secp256k1_pubkey*) pubkey_combine(
            scope const(secp256k1_pubkey*[]) pubkeys) const {
        //const _pubkeys=&pubkeys;
        //auto _pubkeys = pubkeys.map!(pkey => cast(secp256k1_pubkey*)&pkey[0]).array;
        pragma(msg, "__pubkeys ", typeof(&pubkeys[0]));
        //pragma(msg, "X__pubkeys ", typeof(&((&_pubkeys[0])[0])));
        //    pragma(msg, "X__pubkeys ", typeof(&pubkeys[0]));
        auto output_pubkey = new secp256k1_pubkey;
        const ret = secp256k1_ec_pubkey_combine(_ctx, output_pubkey, &pubkeys[0], pubkeys.length);
        return output_pubkey;
    }

    @trusted
    const(ubyte[]) xonly_pubkey_serialize(
            const(secp256k1_xonly_pubkey*) xonly_pubkey) const {
        auto pubkey = new ubyte[XONLY_PUBKEY_SIZE];
        secp256k1_xonly_pubkey_serialize(_ctx, &pubkey[0], xonly_pubkey);
        return pubkey;

    }
}

version (unittest) {
    import tagion.utils.Miscellaneous : toHexString, decode;
}

unittest {
    import std.traits;

    /+
 + This tests verify_ecdsa() for a valid signature
 +/{
        auto data = decode("CF80CD8AED482D5D1527D7DC72FCEFF84E6326592848447D2DC0B0E87DFC9A90"); //sha256hash of "testing"
        auto sig = decode("3044022079BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F817980220294F14E883B3F525B5367756C2A11EF6CF84B730B36C17CB0C56F0AAB2C98589");
        auto pub = decode("040A629506E1B65CD9D2E0BA9C75DF9C4FED0DB16DC9625ED14397F0AFC836FAE595DC53F8B0EFE61E703075BD9B143BAC75EC0E19F82A2208CAEB32BE53414C40");
        try {
            auto crypt = new NativeSecp256k1(NativeSecp256k1.Format.DER);
            auto result = crypt.verify_ecdsa(data, sig, pub);
            assert(result);
        }
        catch (ConsensusException e) {
            assert(0, e.msg);
        }
    }

    /++
 + This tests verify_ecdsa() for a non-valid signature
 +/
    {
        auto data = decode("CF80CD8AED482D5D1527D7DC72FCEFF84E6326592848447D2DC0B0E87DFC9A91"); //sha256hash of "testing"
        auto sig = decode("3044022079BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F817980220294F14E883B3F525B5367756C2A11EF6CF84B730B36C17CB0C56F0AAB2C98589");
        auto pub = decode("040A629506E1B65CD9D2E0BA9C75DF9C4FED0DB16DC9625ED14397F0AFC836FAE595DC53F8B0EFE61E703075BD9B143BAC75EC0E19F82A2208CAEB32BE53414C40");
        try {
            auto crypt = new NativeSecp256k1(NativeSecp256k1.Format.DER);
            auto result = crypt.verify_ecdsa(data, sig, pub);
            assert(!result);
        }
        catch (ConsensusException e) {
            assert(0, e.msg);
        }
    }

    /++
 + This tests secret key verify_ecdsa() for a valid secretkey
 +/
    {
        auto sec = decode("67E56582298859DDAE725F972992A07C6C4FB9F62A8FFF58CE3CA926A1063530");
        try {
            auto crypt = new NativeSecp256k1(NativeSecp256k1.Format.DER);
            auto result = crypt.secKeyVerify(sec);
            assert(result);
        }
        catch (ConsensusException e) {
            assert(0, e.msg);
        }
    }

    /++
 + This tests secret key verify_ecdsa() for an invalid secretkey
 +/
    {
        auto sec = decode("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF");
        try {
            auto crypt = new NativeSecp256k1;
            auto result = crypt.secKeyVerify(sec);
            assert(!result);
        }
        catch (ConsensusException e) {
            assert(0, e.msg);
        }
    }

    /++
 + This tests public key create() for a invalid secretkey
 +/
    {
        auto sec = decode("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF");
        try {
            auto crypt = new NativeSecp256k1(NativeSecp256k1.Format.DER);
            auto resultArr = crypt.computePubkey(sec);
            assert(0, "This test should throw an ConsensusException");
        }
        catch (ConsensusException e) {
            assert(e.code == ConsensusFailCode.SECURITY_PUBLIC_KEY_CREATE_FAULT); // auto pubkeyString = resultArr.toHexString!true;
            // assert( pubkeyString == "0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000");
        }

    }

    /++
 + This tests sign() for a valid secretkey
 +/
    {
        auto data = decode("CF80CD8AED482D5D1527D7DC72FCEFF84E6326592848447D2DC0B0E87DFC9A90"); //sha256hash of "testing"
        auto sec = decode("67E56582298859DDAE725F972992A07C6C4FB9F62A8FFF58CE3CA926A1063530");
        try {
            auto crypt = new NativeSecp256k1(NativeSecp256k1.Format.DER, NativeSecp256k1.Format.DER);
            auto resultArr = crypt.sign(data, sec);
            auto sigString = resultArr.toHexString!true;
            assert(sigString == "30440220182A108E1448DC8F1FB467D06A0F3BB8EA0533584CB954EF8DA112F1D60E39A202201C66F36DA211C087F3AF88B50EDF4F9BDAA6CF5FD6817E74DCA34DB12390C6E9");
        }
        catch (ConsensusException e) {
            assert(0, e.msg);
        }
    }

    /++
 + This tests sign() for a invalid secretkey
 +/
    {
        auto data = decode("CF80CD8AED482D5D1527D7DC72FCEFF84E6326592848447D2DC0B0E87DFC9A90"); //sha256hash of "testing"
        auto sec = decode("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF");
        try {
            auto crypt = new NativeSecp256k1(NativeSecp256k1.Format.DER, NativeSecp256k1.Format.DER);
            auto resultArr = crypt.sign(data, sec);
            assert(0, "This test should throw an ConsensusException");
        }
        catch (ConsensusException e) {
            assert(e.code == ConsensusFailCode.SECURITY_SIGN_FAULT);
        }
    }

    /++
 + This tests private key tweak-add
 +/
    {
        auto sec = decode("67E56582298859DDAE725F972992A07C6C4FB9F62A8FFF58CE3CA926A1063530");
        auto data = decode("3982F19BEF1615BCCFBB05E321C10E1D4CBA3DF0E841C2E41EEB6016347653C3"); //sha256hash of "tweak"
        try {
            auto crypt = new NativeSecp256k1(NativeSecp256k1.Format.DER, NativeSecp256k1.Format.DER);
            ubyte[] resultArr;
            crypt.privKeyTweakAdd(sec, data, resultArr);
            auto sigString = resultArr.toHexString!true;
            assert(sigString == "A168571E189E6F9A7E2D657A4B53AE99B909F7E712D1C23CED28093CD57C88F3");
        }
        catch (ConsensusException e) {
            assert(0, e.msg);
        }
    }

    /++
 + This tests private key tweak-mul
 +/
    {
        auto sec = decode("67E56582298859DDAE725F972992A07C6C4FB9F62A8FFF58CE3CA926A1063530");
        auto data = decode("3982F19BEF1615BCCFBB05E321C10E1D4CBA3DF0E841C2E41EEB6016347653C3"); //sha256hash of "tweak"
        try {
            auto crypt = new NativeSecp256k1(NativeSecp256k1.Format.DER, NativeSecp256k1.Format.DER);
            ubyte[] resultArr;
            crypt.privKeyTweakMul(sec, data, resultArr);
            auto sigString = resultArr.toHexString!true;
            assert(sigString == "97F8184235F101550F3C71C927507651BD3F1CDB4A5A33B8986ACF0DEE20FFFC");
        }
        catch (ConsensusException e) {
            assert(0, e.msg);
        }
    }

    /++
 + This tests private key tweak-add uncompressed
 +/
    {
        auto pub = decode("040A629506E1B65CD9D2E0BA9C75DF9C4FED0DB16DC9625ED14397F0AFC836FAE595DC53F8B0EFE61E703075BD9B143BAC75EC0E19F82A2208CAEB32BE53414C40");
        auto data = decode("3982F19BEF1615BCCFBB05E321C10E1D4CBA3DF0E841C2E41EEB6016347653C3"); //sha256hash of "tweak"
        try {
            auto crypt = new NativeSecp256k1(NativeSecp256k1.Format.DER, NativeSecp256k1.Format.DER);
            auto resultArr = crypt.pubKeyTweakAdd(pub, data, false);
            auto sigString = resultArr.toHexString!true;
            assert(sigString == "0411C6790F4B663CCE607BAAE08C43557EDC1A4D11D88DFCB3D841D0C6A941AF525A268E2A863C148555C48FB5FBA368E88718A46E205FABC3DBA2CCFFAB0796EF");
        }
        catch (ConsensusException e) {
            assert(0, e.msg);
        }
    }

    /++
 + This tests private key tweak-mul uncompressed
 +/
    {
        auto pub = decode("040A629506E1B65CD9D2E0BA9C75DF9C4FED0DB16DC9625ED14397F0AFC836FAE595DC53F8B0EFE61E703075BD9B143BAC75EC0E19F82A2208CAEB32BE53414C40");
        auto data = decode("3982F19BEF1615BCCFBB05E321C10E1D4CBA3DF0E841C2E41EEB6016347653C3"); //sha256hash of "tweak"
        try {
            auto crypt = new NativeSecp256k1(NativeSecp256k1.Format.DER, NativeSecp256k1.Format.DER);
            auto resultArr = crypt.pubKeyTweakMul(pub, data, false);
            auto sigString = resultArr.toHexString!true;
            assert(sigString == "04E0FE6FE55EBCA626B98A807F6CAF654139E14E5E3698F01A9A658E21DC1D2791EC060D4F412A794D5370F672BC94B722640B5F76914151CFCA6E712CA48CC589");
        }
        catch (ConsensusException e) {
            assert(0, e.msg);
        }
    }

    /++
 + This tests seed randomization
 +/
    {
        try {
            auto crypt = new NativeSecp256k1(
                    NativeSecp256k1.Format.DER, NativeSecp256k1.Format.DER);
            auto result = crypt.randomizeContext;
            assert(result);
        }
        catch (ConsensusException e) {
            assert(0, e.msg);
        }
    }

    {
        auto message = decode("CF80CD8AED482D5D1527D7DC72FCEFF84E6326592848447D2DC0B0E87DFC9A90");
        //auto message= decode("CF80CD8AED482D5D1527D7DC72FCEFF84E6326592848447D2DC0B0E87DFC9A9A");
        auto seed = decode("A441B15FE9A3CF5661190A0B93B9DEC7D04127288CC87250967CF3B52894D110"); //sha256hash of "random"
        import tagion.utils.Miscellaneous : toHexString;
        import std.digest.sha;

        try {
            auto crypt = new NativeSecp256k1;
            auto data = seed.dup;
            do {
                data = sha256Of(data).dup;
            }
            while (!crypt.secKeyVerify(data));
            immutable privkey = data.idup;
            immutable pubkey = crypt.computePubkey(privkey);

            immutable signature = crypt.sign(message, privkey);
            assert(crypt.verify(message, signature, pubkey));
        }
        catch (ConsensusException e) {
            assert(0, e.msg);
        }

    }

    { //
        auto crypt = new NativeSecp256k1(NativeSecp256k1.Format.DER, NativeSecp256k1.Format.DER);
        auto sec = decode("67E56582298859DDAE725F972992A07C6C4FB9F62A8FFF58CE3CA926A1063530");
        immutable privkey = sec.idup;
        //        auto privkey = crypt.secKeyVerify( sec );
        assert(crypt.secKeyVerify(privkey));
        immutable pubkey = crypt.computePubkey(privkey);

        // Message
        auto message = decode("CF80CD8AED482D5D1527D7DC72FCEFF84E6326592848447D2DC0B0E87DFC9A90");
        auto signature = crypt.sign(message, privkey);
        assert(crypt.verify(message, signature, pubkey));

        // Drived key a
        const drive = decode("ABCDEF");
        ubyte[] privkey_a_drived;
        crypt.privKeyTweakMul(privkey, drive, privkey_a_drived);
        assert(privkey != privkey_a_drived);
        auto pubkey_a_drived = crypt.pubKeyTweakMul(pubkey, drive);
        assert(pubkey != pubkey_a_drived);
        auto signature_a_drived = crypt.sign(message, privkey_a_drived);
        assert(crypt.verify(message, signature_a_drived, pubkey_a_drived));

        // Drive key b from key a
        ubyte[] privkey_b_drived;
        crypt.privKeyTweakMul(privkey_a_drived, drive, privkey_b_drived);
        assert(privkey_b_drived != privkey_a_drived);
        auto pubkey_b_drived = crypt.pubKeyTweakMul(pubkey_a_drived, drive);
        assert(pubkey_b_drived != pubkey_a_drived);
        auto signature_b_drived = crypt.sign(message, privkey_b_drived);
        assert(crypt.verify(message, signature_b_drived, pubkey_b_drived));

    }

    {
        auto crypt = new NativeSecp256k1(NativeSecp256k1.Format.COMPACT, NativeSecp256k1
                .Format.COMPACT);
        auto sec = decode("67E56582298859DDAE725F972992A07C6C4FB9F62A8FFF58CE3CA926A1063530");
        immutable privkey = sec.idup;
        //        auto privkey = crypt.secKeyVerify( sec );
        assert(crypt.secKeyVerify(privkey));
        immutable pubkey = crypt.computePubkey(privkey);

        // Message
        auto message = decode("CF80CD8AED482D5D1527D7DC72FCEFF84E6326592848447D2DC0B0E87DFC9A90");
        auto signature = crypt.sign(message, privkey);
        assert(crypt.verify(message, signature, pubkey));

    }

    {
        auto crypt = new NativeSecp256k1(NativeSecp256k1.Format.RAW, NativeSecp256k1.Format.RAW);
        auto sec = decode("67E56582298859DDAE725F972992A07C6C4FB9F62A8FFF58CE3CA926A1063530");
        immutable privkey = sec.idup;
        //        auto privkey = crypt.secKeyVerify( sec );
        assert(crypt.secKeyVerify(privkey));
        immutable pubkey = crypt.computePubkey(privkey);

        // Message
        auto message = decode("CF80CD8AED482D5D1527D7DC72FCEFF84E6326592848447D2DC0B0E87DFC9A90");
        auto signature = crypt.sign(message, privkey);
        assert(crypt.verify(message, signature, pubkey));

    }

    {
        auto crypt = new NativeSecp256k1(NativeSecp256k1.Format.AUTO, NativeSecp256k1.Format.DER);
        auto sec = decode("67E56582298859DDAE725F972992A07C6C4FB9F62A8FFF58CE3CA926A1063530");
        immutable privkey = sec.idup;
        //        auto privkey = crypt.secKeyVerify( sec );
        assert(crypt.secKeyVerify(privkey));
        immutable pubkey = crypt.computePubkey(privkey);

        // Message
        auto message = decode("CF80CD8AED482D5D1527D7DC72FCEFF84E6326592848447D2DC0B0E87DFC9A90");
        auto signature = crypt.sign(message, privkey);
        assert(crypt.verify(message, signature, pubkey));

    }

    {
        auto crypt = new NativeSecp256k1(NativeSecp256k1.Format.AUTO, NativeSecp256k1
                .Format.COMPACT);
        auto sec = decode("67E56582298859DDAE725F972992A07C6C4FB9F62A8FFF58CE3CA926A1063530");
        immutable privkey = sec.idup;
        //        auto privkey = crypt.secKeyVerify( sec );
        assert(crypt.secKeyVerify(privkey));
        immutable pubkey = crypt.computePubkey(privkey);

        // Message
        auto message = decode("CF80CD8AED482D5D1527D7DC72FCEFF84E6326592848447D2DC0B0E87DFC9A90");
        auto signature = crypt.sign(message, privkey);
        assert(crypt.verify(message, signature, pubkey));

    }

    {
        auto crypt = new NativeSecp256k1(NativeSecp256k1.Format.RAW, NativeSecp256k1.Format.RAW);
        auto sec = decode("67E56582298859DDAE725F972992A07C6C4FB9F62A8FFF58CE3CA926A1063530");
        immutable privkey = sec.idup;
        //        auto privkey = crypt.secKeyVerify( sec );
        assert(crypt.secKeyVerify(privkey));
        immutable pubkey = crypt.computePubkey(privkey);

        // Message
        auto message = decode("CF80CD8AED482D5D1527D7DC72FCEFF84E6326592848447D2DC0B0E87DFC9A90");
        auto signature = crypt.sign(message, privkey);

        assert(crypt.verify(message, signature, pubkey));

    }

    //Test ECDH
    {
        import std.stdio;

        auto crypt = new NativeSecp256k1(NativeSecp256k1.Format.RAW, NativeSecp256k1.Format.RAW);

        const aliceSecretKey = decode(
                "37cf9a0f624a21b0821f4ab3f711ac3a86ac3ae8e4d25bdbd8cdcad7b6cf92d4");
        const alicePublicKey = crypt.computePubkey(aliceSecretKey, false);

        const bobSecretKey = decode(
                "2f402cd0753d3afca00bd3f7661ca2f882176ae4135b415efae0e9c616b4a63e");
        const bobPublicKey = crypt.computePubkey(bobSecretKey, false);

        assert(alicePublicKey.toHexString == "0451958fb5c78264dc67edec62ad7cb0722ca7468e9781c1aebc0c05c5e8be05daa916301e6267fed2a662c9d727da9c3ffa4eab9f76dd848f60ef44d2917cf7ee");
        assert(bobPublicKey.toHexString == "0489685350631b9fee83158aa55980af0969305f698ebe3b9475a36340d0b1996719e1f6b4c21cffdadc158e5b07e71b70d7b87b7ad1c3e6df8f78ad419de767a6");

        const aliceResult = crypt.createECDHSecret(aliceSecretKey, bobPublicKey);
        const bobResult = crypt.createECDHSecret(bobSecretKey, alicePublicKey);

        assert(aliceResult == bobResult);
    }

}

unittest { /// Schnorr test generated from the secp256k1/examples/schnorr.c 

    //import std.stdio;

    const aux_random = decode("b0d8d9a460ddcea7ae5dc37a1b5511eb2ab829abe9f2999e490beba20ff3509a");
    const msg_hash = decode("1bd69c075dd7b78c4f20a698b22a3fb9d7461525c39827d6aaf7a1628be0a283");
    const secret_key = decode("e46b4b2b99674889342c851f890862264a872d4ac53a039fbdab91fd68ed4e71");
    const expected_pubkey = decode("ecd21d66cf97843d467c9d02c5781ec1ec2b369620605fd847bd23472afc7e74");
    const expected_signature = decode(
            "021e9a32a12ead3144bb230a81794913a856296ed369159d01b8f57d6d7e7d3630e34f84d49ec054d5251ff6539f24b21097a9c39329eaab2e9429147d6d82f8");
    const expected_keypair = decode("e46b4b2b99674889342c851f890862264a872d4ac53a039fbdab91fd68ed4e71747efc2a4723bd47d85f602096362becc11e78c5029d7c463d8497cf661dd2eca89c1820ccc2dd9b0e0e5ab13b1454eb3c37c31308ae20dd8d2aca2199ff4e6b");
    auto crypt = new NativeSecp256k1;
    secp256k1_keypair keypair;
    crypt.createKeyPair(secret_key, keypair);
    //writefln("keypair %(%02x%)", keypair);
    assert(keypair.data == expected_keypair);
    const signature = crypt
        .sign_schnorr(msg_hash, keypair, aux_random);
    assert(signature == expected_signature);
    //writefln("expected_pubkey %(%02x%)", expected_pubkey);
    const pubkey = crypt.xonly_pubkey(keypair); //writefln("         pubkey %(%02x%)", pubkey);
    assert(pubkey == expected_pubkey);
    const signature_ok = crypt
        .verify_schnorr(signature, msg_hash, pubkey);
    //writefln("Signed %s", signature_ok);
    assert(signature_ok, "Schnorr signing failded");
}

version (unittest) {
    const(ubyte[]) sha256(scope const(ubyte[]) data) {
        import std.digest.sha : SHA256;
        import std.digest;

        return digest!SHA256(data).dup;
    }
}

unittest {
    import std.algorithm;
    import std.array;
    import std.range;
    import std.stdio;

    //https://github.com/guggero/bip-schnorr.github
    const privkeys = [
        "b2b084220e17de5bb85c6b33fe4630dc0cc3a0382c49509461a26341bc3c27e4",
        "704550de854bdac387698eac6fb959f72c9a7aac064ec2a6bceb10a875b9cc6e",
        "e37c7c6335cb98a4c229b975c66c9b60351b26c6c227f66a2c854fb7c0be58be"
    ]
        .map!(hex => decode(hex))
        .array;
    const expected_pubkeys = [
        "1b34e02fbfab6153513c7578de070e1c9f2654b88109fb3906bb7f63dffd957d",
        "bdaa2178ad0db31880dc326b1f8a6a383efd9a579962aac7008d8af738fa814d",
        "8810e83afc4412af9070102e22305c8ae85aad98aa84263db47149f1c9790500"
    ]
        .map!(hex => decode(hex))
        .array;
    const coefficients = [
        "3260a9a6c5a36e6e539cdfe022f9eee5beebdfd9c84f1f9a8673c00c2f488fab",
        "eb78a85820fa35c5cf1685602294b12423a2d7a789542839b0f1a490eb0893a8",
        "7da6ad28e2400fba5a14c3c2aaed0b69c0c25b38a7eb4f6109544d3bc9cc5cdb"
    ]
        .map!(hex => decode(hex))
        .array;
    const ell = "310c965e674daa3d91ccd77817e104b0a15c12749bb08c90adcc13b3a554add8"
        .decode;
    const pubKeyCombined = "8a58f1ae3b94700e82803522dfac149ea31b270c0ff0187efc060f67138e6b9d"
        .decode;
    const message = "746869735f636f756c645f62655f7468655f686173685f6f665f615f6d736721"
        .decode;
    const sessionIds = [
        "bbd16447f4f4aa718c5b156863bb7c4f14761789dc3b861941d2eea9a8696c08",
        "096882f29d12a54360530088f0f533ac471431e1976b707fc93df166db12ec91",
        "7cd8e69d70829983b61c045a0d7421468a0e9473c4097ade659623ef247ba27a"
    ]
        .map!(hex => decode(hex))
        .array;
    const commitments = [
        "c9813f85fd47c5fea9ee81ab70de1a1ad29789ff654b4f14f3c130f136e0c51e",
        "73076409318d4b6f68a41ef631d38d0ef5a2bdebc230ece7f0274f7e5f845abd",
        "13ea03ceef690298f14b02831f3c25cc28efd6967a5d5e0b6449009a7e8edca5"
    ]
        .map!(hex => decode(hex))
        .array;
    const secretKeys = [
        "3aa16f18ec8c3dcbf8dd9c8f9ff504bd87b27d81d0ab2cb9026de18853db9274",
        "df954a3b7af8fba50f7e0834d2e214ffb43050104c6ae0bcbc2e9bcab93c280c",
        "be1df607cd9969d583cf6c93585483d87d28e9ba285f6b56336ca187550cb8ae"
    ]
        .map!(hex => decode(hex))
        .array;
    const secretNonces = [
        "8b222c19b413c19d7acf9c541dae7ceed687edd3151e800750e9e0def14e7ade",
        "b2a0a71f2427ef436097204d8c4bd10209d9a497c9b7ea52b86a04cbb0a03c6b",
        "c838b589b2c6b78753d3e659f5e0f985ca6e616a6076b76b074b76cbcdc6a7e4"
    ]
        .map!(hex => decode(hex))
        .array;
    const nonceCombined = "4bcc50fce8d9ff8ddf1539446e2bea9a62101267c7894ca3193b7fd73505a0d0"
        .decode;
    const partialSigs = [
        "beeef9e49bf554534a96116999e49f9123f417828c949702e3ee1679663ec913",
        "788dfaf7a335e37d705b56637ca3062839cebef529cd11b10fea9d3432be15e6",
        "752f03f84ef70713016cb38031d56725f10bfab013513c2cba66e62b0cfc7ade"
    ]
        .map!(hex => decode(hex))
        .array;
    const signature = "4bcc50fce8d9ff8ddf1539446e2bea9a62101267c7894ca3193b7fd73505a0d0acabf8d48e223ee3bc5e1b4d485d0ce0941ff4411a6a44a4ee6d3b4bd5c31896"
        .decode;
    NativeSecp256k1[] crypts = iota(
            privkeys.length)
        .map!(i => new NativeSecp256k1)
        .array;
    secp256k1_keypair[] keypairs;
    keypairs
        .length = crypts.length;
    crypts
        .enumerate
        .each!((iter) => iter.value
                .createKeyPair(
                    privkeys[iter.index], keypairs[iter
                        .index]));
    const pubkeys = crypts
        .enumerate
        .map!((iter) => iter.value.xonly_pubkey(
                keypairs[iter.index]))
        .array;
    expected_pubkeys
        .each!(pkey => writefln(
                "%(%02x%)", pkey));
    pubkeys
        .each!(pkey => writefln("%(%02x%)", pkey));
    assert(equal(expected_pubkeys, pubkeys));

    const combined = sha256(pubkeys
            .join);
    writefln("combined=%(%02x%)", combined);
    assert(combined == ell);
}

version (none) unittest {
    // https://guggero.github.io/cryptography-toolkit/#!/mu-sig
    import std.algorithm;
    import std.array;
    import std.range;
    import std.stdio;
    import tagion.basic.basic : unitfile;
    import std.file : readText;
    import std.traits;
    import std.json;
    import std.bitmanip : nativeToLittleEndian;
    import std.string : representation;

    const common_crypt = new NativeSecp256k1;
    @safe
    static struct TestData {
        const(ubyte[][]) privKeys;
        const(ubyte[][]) pubKeys;
        const(ubyte[][]) coefficients;
        const(ubyte[]) ell;
        const(ubyte[]) pubKeyCombined;
        const(ubyte[]) message;
        const(ubyte[][]) sessionIds;
        const(ubyte[][]) commitments;
        const(ubyte[][]) secretKeys;
        const(ubyte[][]) secretNonces;
        const(ubyte[]) nonceCombined;
        const(ubyte[][]) partialSigs;
        const(ubyte[]) signature;
        this(JSONValue json) @trusted {
            static foreach (i, name; [FieldNameTuple!TestData]) {
                {
                    auto sub_json = json[name];
                    static if (is(
                            Fields!TestData[i] == const(ubyte[]))) {
                        this.tupleof[i] = sub_json.str.decode;
                    }
                    else {
                        this.tupleof[i] = sub_json
                            .array[]
                            .map!(json => json.str)
                            .map!(hex => hex.decode)
                            .array;

                    }
                }
            }
        }
    }

    immutable text_data = unitfile("test-vectors-mu-sig.json").readText;
    auto list_of_tests = (() @trusted => text_data.parseJSON.array[])()
        .map!(json => TestData(json));
    list_of_tests.popFront;
    const BTC_MUSIG_TAG = sha256("MuSig coefficient".representation);
    @safe
    void check_musig(
            TestData test_data) {
        with (test_data) {
            writefln("message=%(%02x%)", message);
            NativeSecp256k1[] crypts = iota(privKeys.length)
                .map!(i => new NativeSecp256k1)
                .array;
            ubyte[][] keypairs;
            keypairs.length = crypts.length;
            crypts
                .enumerate
                .each!((iter) => iter
                        .value
                        .createKeyPair(privKeys[iter.index], keypairs[iter.index]));
            const created_pubKeys = crypts
                .enumerate
                .map!((iter) => iter
                        .value.xonly_pubkey(keypairs[iter.index]))
                .array;
            pubKeys
                .each!(pkey => writefln("%(%02x%)", pkey));
            created_pubKeys
                .each!(pkey => writefln("%(%02x%)", pkey));
            assert(equal(pubKeys, created_pubKeys));
            //
            // Step 1 Combine public keys
            //
            const created_pubKeyHash = sha256(created_pubKeys
                    .join);
            writefln("pubKeyHash=%(%02x%)", created_pubKeyHash);
            writefln("pubKeyHash=%(%02x%)", ell);
            assert(created_pubKeyHash == ell);

            auto index_range = iota(cast(uint) crypts.length);
            auto created_coefficients = index_range
                .map!(index =>
                        sha256(
                            only(
                            BTC_MUSIG_TAG, BTC_MUSIG_TAG,
                            created_pubKeyHash,
                            nativeToLittleEndian(index))
                            .join
                        )
            );
            writeln("coefficients");
            coefficients
                .each!(coef => writefln("%(%02x%)", coef));
            writeln("created_coefficients");
            created_coefficients
                .each!(coef => writefln("%(%02x%)", coef));
            assert(equal(created_coefficients, coefficients));
            //
            // Combine the hash and the keys
            //
            const(secp256k1_pubkey*)[] tweaked_pubkeys;
            foreach (
                uint i, pubkey, coefficient; zip(index_range, created_pubKeys, created_coefficients)) {
                writefln("%d %(%02x%)", i, pubkey);
                writefln("%d %(%02x%)", i, coefficient);
                auto tweaked_pubkey = common_crypt
                    .xonly_pubkey_tweak(pubkey, coefficient);
                tweaked_pubkeys ~= tweaked_pubkey;
                const xonly_pubkey = common_crypt.xonly_from_pubkey(tweaked_pubkey);
                writefln("%d xonly_pubkey %(%02x%)", i, xonly_pubkey.data);
                const pubkey_32 = common_crypt.xonly_pubkey_serialize(xonly_pubkey);
                writefln("%d xonly 32     %(%02x%)", i, pubkey_32);
            }
            tweaked_pubkeys.each!(pkey => writefln("%(%02x%)", pkey.data));
            const created_pubKeyCombined = common_crypt.pubkey_combine(tweaked_pubkeys);
            writefln("pubKeyCombined        =%(%02x%)", pubKeyCombined);
            writefln("created_pubKeyCombined=%(%02x%)", created_pubKeyCombined.data);

        }
    }

    pragma(msg, "pubKeyHash ", typeof(
            list_of_tests
            .front));
    check_musig(list_of_tests.front);
}
