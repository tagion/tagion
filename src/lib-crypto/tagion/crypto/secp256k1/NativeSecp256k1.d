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

private import tagion.crypto.secp256k1.c.secp256k1;
private import tagion.crypto.secp256k1.c.secp256k1_ecdh;

import std.exception : assumeUnique;
import tagion.basic.ConsensusExceptions;

import tagion.utils.Miscellaneous : toHexString;

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
@safe
class NativeSecp256k1 {
    @safe
    static void check(bool flag, ConsensusFailCode code, string file = __FILE__, size_t line = __LINE__) {
        if (!flag) {
            throw new SecurityConsensusException(code, file, line);
        }
    }

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
        //        auto ctx=getContext();
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
        //        auto ctx=getContext();
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
        ubyte* _result = result.ptr;

        int ret = secp256k1_ec_pubkey_parse(_ctx, &pubkey_result, pubdata, publen);
        check(ret == 1, ConsensusFailCode.SECURITY_PUBLIC_KEY_PARSE_FAULT);

        //if (ret) {
        ret = secp256k1_ecdh(_ctx, _result, &pubkey_result, secdata, null, null);
        //}
        check(ret == 1, ConsensusFailCode.SECURITY_EDCH_FAULT);

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

//@safe
unittest {
    import tagion.utils.Miscellaneous : toHexString, decode;
    import std.traits;

    /+
 + This tests verify() for a valid signature
 +/{
        auto data = decode("CF80CD8AED482D5D1527D7DC72FCEFF84E6326592848447D2DC0B0E87DFC9A90"); //sha256hash of "testing"
        auto sig = decode("3044022079BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F817980220294F14E883B3F525B5367756C2A11EF6CF84B730B36C17CB0C56F0AAB2C98589");
        auto pub = decode("040A629506E1B65CD9D2E0BA9C75DF9C4FED0DB16DC9625ED14397F0AFC836FAE595DC53F8B0EFE61E703075BD9B143BAC75EC0E19F82A2208CAEB32BE53414C40");
        try {
            auto crypt = new NativeSecp256k1(NativeSecp256k1.Format.DER);

            auto result = crypt.verify(data, sig, pub);
            assert(result);
        }
        catch (ConsensusException e) {
            assert(0, e.msg);
        }
    }

    /++
 + This tests verify() for a non-valid signature
 +/
    {
        auto data = decode("CF80CD8AED482D5D1527D7DC72FCEFF84E6326592848447D2DC0B0E87DFC9A91"); //sha256hash of "testing"
        auto sig = decode("3044022079BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F817980220294F14E883B3F525B5367756C2A11EF6CF84B730B36C17CB0C56F0AAB2C98589");
        auto pub = decode("040A629506E1B65CD9D2E0BA9C75DF9C4FED0DB16DC9625ED14397F0AFC836FAE595DC53F8B0EFE61E703075BD9B143BAC75EC0E19F82A2208CAEB32BE53414C40");
        try {
            auto crypt = new NativeSecp256k1(NativeSecp256k1.Format.DER);
            auto result = crypt.verify(data, sig, pub);
            assert(!result);
        }
        catch (ConsensusException e) {
            assert(0, e.msg);
        }
    }

    /++
 + This tests secret key verify() for a valid secretkey
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
 + This tests secret key verify() for an invalid secretkey
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
            assert(e.code == ConsensusFailCode.SECURITY_PUBLIC_KEY_CREATE_FAULT);
            // auto pubkeyString = resultArr.toHexString!true;
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
        auto seed = decode("A441B15FE9A3CF5661190A0B93B9DEC7D04127288CC87250967CF3B52894D110"); //sha256hash of "random"
        try {
            auto crypt = new NativeSecp256k1(NativeSecp256k1.Format.DER, NativeSecp256k1.Format.DER);
            auto result = crypt.randomize(seed);
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

        const aliceSecretKey = decode("37cf9a0f624a21b0821f4ab3f711ac3a86ac3ae8e4d25bdbd8cdcad7b6cf92d4");
        const alicePublicKey = crypt.computePubkey(aliceSecretKey, false);

        const bobSecretKey = decode("2f402cd0753d3afca00bd3f7661ca2f882176ae4135b415efae0e9c616b4a63e");
        const bobPublicKey = crypt.computePubkey(bobSecretKey, false);

        assert(alicePublicKey.toHexString == "0451958fb5c78264dc67edec62ad7cb0722ca7468e9781c1aebc0c05c5e8be05daa916301e6267fed2a662c9d727da9c3ffa4eab9f76dd848f60ef44d2917cf7ee");
        assert(bobPublicKey.toHexString == "0489685350631b9fee83158aa55980af0969305f698ebe3b9475a36340d0b1996719e1f6b4c21cffdadc158e5b07e71b70d7b87b7ad1c3e6df8f78ad419de767a6");

        const aliceResult = crypt.createECDHSecret(aliceSecretKey, bobPublicKey);
        const bobResult = crypt.createECDHSecret(bobSecretKey, alicePublicKey);

        assert(aliceResult == bobResult);
    }

    version (none) { // Test 1 ECDH
        auto crypt = new NativeSecp256k1(NativeSecp256k1.Format.RAW, NativeSecp256k1.Format.RAW);
        import std.stdio;

        //writefln("%d", "039c28258a97c779c88212a0e37a74ec90898c63b60df60a7d05d0424f6f6780".length);
        const privKey = decode("039c28258a97c779c88212a0e37a74ec90898c63b60df60a7d05d0424f6f6780");

        //        writefln(
        const pubKey = crypt.computePubkey(privKey, false);
        writefln("privKey=%s", privKey.toHexString!true);
        writefln("privKey=%s", pubKey.toHexString!true);
        writefln("       =%s", "049E35EFD4390AB5AB1CBD5C273D0D23E6D46C8CCF966C2CC62A4196AC58967AB9   7735ACB05E8646C557EF824F118C9B66AF162FCFAD14B91A145BC55693C342E6");
        assert(pubKey.toHexString!true == "049E35EFD4390AB5AB1CBD5C273D0D23E6D46C8CCF966C2CC62A4196AC58967AB97735ACB05E8646C557EF824F118C9B66AF162FCFAD14B91A145BC55693C342E6");

        const ciphertextPrivKey = decode("f2785178d20217ed89e982ddca6491ed21d598d8545db503f1dee5e09c747164");

        ubyte[] sharedECCKey;

        //const sharedECCKey = crypt.computePubkey(ciphertextPrivKey, false);
        crypt.privKeyTweakMul(ciphertextPrivKey, pubKey, sharedECCKey);
        //crypt.privKeyTweakMul(ciphertextPrivKey, pubKey, sharedECCKey);
        writefln("ciphertextPrivKey %s", ciphertextPrivKey.toHexString!true);
        writefln("sharedECCKey %s", sharedECCKey.toHexString!true);
        writefln("             %s", "46defe934a709bf55328ad593b62884079f908d6a6ebbc2bdbc93b77e3506181   6e287b5665a9b5f0fdb08a1f3f63557849525df1e4ece2c717fd0de1e0a7330f");

        secp256k1_pubkey sharedECCKey1;
        //        ubyte[] sharedECCKey1;
        auto sharedECCKey1_ptr = &sharedECCKey1; //sharedECCKey1[0];
        const(ubyte*) ciphertextPrivKey_ptr = &ciphertextPrivKey[0];
        int ret = secp256k1_ec_pubkey_create(crypt._ctx, sharedECCKey1_ptr, ciphertextPrivKey_ptr);
        writefln("sharedECCKey1 %s", sharedECCKey1.data.toHexString!true);

        //  "f2785178d20217ed89e982ddca6491ed21d598d8545db503f1dee5e09c747164");
    }
}
