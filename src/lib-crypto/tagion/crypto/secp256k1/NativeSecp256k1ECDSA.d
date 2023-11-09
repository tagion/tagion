module tagion.crypto.secp256k1.NativeSecp256k1ECDSA;

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

//private import tagion.crypto.secp256k1.c.secp256k1_hash;
//private import tagion.crypto.secp256k1.c.secp256k1_schnorrsig;
//private import tagion.crypto.secp256k1.c.secp256k1_extrakeys;

import tagion.crypto.secp256k1.NativeSecp256k1Interface;

import std.exception : assumeUnique;
import tagion.basic.ConsensusExceptions;

import tagion.utils.Miscellaneous : toHexString;
import std.algorithm;
import std.array;

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
class NativeSecp256k1ECDSA : NativeSecp256k1Interface {
    static void check(bool flag, ConsensusFailCode code, string file = __FILE__, size_t line = __LINE__) pure {
        if (!flag) {
            throw new SecurityConsensusException(code, file, line);
        }
    }

    protected secp256k1_context* _ctx;

    @trusted
    this(const SECP256K1 flag = SECP256K1.CONTEXT_SIGN | SECP256K1.CONTEXT_VERIFY) nothrow {
        _ctx = secp256k1_context_create(flag);
        scope (exit) {
            randomizeContext;
        }
    }

    /++
     + Verifies the given secp256k1 signature in native code.
     + Calling when enabled == false is undefined (probably library not loaded)

     + Params:
     +       msg            = The message which was signed, must be exactly 32 bytes
     +       signature      = The signature
     +       pub            =  The public key which did the signing
     +/
    @trusted
    bool verify(const(ubyte[]) msg, const(ubyte[]) signature, const(ubyte[]) pub) const
    in (msg.length == MESSAGE_SIZE)
    in (signature.length == SIGNATURE_SIZE)
    in (pub.length <= 520)
    do {
        secp256k1_ecdsa_signature sig;
        secp256k1_pubkey pubkey;
        {
            const ret = secp256k1_ecdsa_signature_parse_compact(_ctx, &sig, &signature[0]);
            check(ret != 0, ConsensusFailCode.SECURITY_SIGNATURE_SIZE_FAULT);
        }
        {
            const ret = secp256k1_ec_pubkey_parse(_ctx, &pubkey, &pub[0], pub.length);
            check(ret == 1, ConsensusFailCode.SECURITY_PUBLIC_KEY_PARSE_FAULT);
        }
        const ret = secp256k1_ecdsa_verify(_ctx, &sig, &msg[0], &pubkey);
        return ret == 1;
    }

    /++
     + libsecp256k1 Create an ECDSA signature.
     +
     + @param msg Message hash, 32 bytes
     + @param key Secret key, 32 bytes
     +
     + Return values
     + @param sig byte array of signature
     +/
    @trusted
    immutable(ubyte[]) sign(const(ubyte[]) msg, scope const(ubyte[]) seckey) const
    in (msg.length == MESSAGE_SIZE)
    in (seckey.length == SECKEY_SIZE)
    do {
        secp256k1_ecdsa_signature sig;
        scope (exit) {
            randomizeContext;

        }

        {
            const ret = secp256k1_ecdsa_sign(_ctx, &sig, &msg[0], &seckey[0], null, null);
            check(ret == 1, ConsensusFailCode.SECURITY_SIGN_FAULT);
        }
        ubyte[SIGNATURE_SIZE] output_ser;
        {
            const ret = secp256k1_ecdsa_signature_serialize_compact(_ctx, &output_ser[0], &sig);
            check(ret == 1, ConsensusFailCode.SECURITY_SIGN_FAULT);
        }
        return output_ser.idup;
    }

    /++
     + libsecp256k1 Seckey Verify - returns true if valid, false if invalid
     +
     + @param seckey ECDSA Secret key, 32 bytes
     +/
    @trusted
    bool secKeyVerify(scope const(ubyte[]) seckey) const nothrow @nogc
    in (seckey.length == SECKEY_SIZE)
    do {
        return secp256k1_ec_seckey_verify(_ctx, &seckey[0]) == 1;
    }

    /++
     + libsecp256k1 Compute Pubkey - computes public key from secret key
     +
     + @param seckey ECDSA Secret key, 32 bytes
     +
     + Return values
     + @param pubkey ECDSA Public key, 33 or 65 bytes
     +/
    enum UN_COMPRESSED_PUBKEY_SIZE = 65;
    enum COMPRESSED_PUBKEY_SIZE = 33;
    @trusted
    immutable(ubyte[]) getPubkey(scope const(ubyte[]) seckey) const
    in (seckey.length == SECKEY_SIZE)
    do {
        secp256k1_pubkey pubkey;

        {
            const ret = secp256k1_ec_pubkey_create(_ctx, &pubkey, &seckey[0]);
            check(ret == 1, ConsensusFailCode.SECURITY_PUBLIC_KEY_CREATE_FAULT);
        }
        ubyte[COMPRESSED_PUBKEY_SIZE] output_ser;
        enum flag = SECP256K1.EC_COMPRESSED;
        size_t outputLen = output_ser.length;
        {
            const ret = secp256k1_ec_pubkey_serialize(_ctx, &output_ser[0], &outputLen, &pubkey, flag);
            check(ret == 1, ConsensusFailCode.SECURITY_PUBLIC_KEY_CREATE_FAULT);
        }
        return output_ser.idup;
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
    void privTweak(
            scope const(ubyte[]) privkey,
    scope const(ubyte[]) tweak,
    out ubyte[] tweak_privkey) const
    in {
        assert(privkey.length == 32);
    }
    do {
        pragma(msg, "fixme(cbr): privkey must be scrambled");
        tweak_privkey = privkey.dup;
        ubyte* _privkey = tweak_privkey.ptr;
        const(ubyte)* _tweak = tweak.ptr;

        int ret = secp256k1_ec_seckey_tweak_mul(_ctx, _privkey, _tweak);
        check(ret == 1, ConsensusFailCode.SECURITY_PRIVATE_KEY_TWEAK_MULT_FAULT);

    }

    alias privTweakMul = privTweak;
    /++
     + libsecp256k1 PrivKey Tweak-Add - Tweak privkey by adding to it
     +
     + @param tweak some bytes to tweak with
     + @param seckey 32-byte seckey
     +/
    @trusted
    final void privTweakAdd(
            const(ubyte[]) privkey,
    const(ubyte[]) tweak,
    out ubyte[] tweak_privkey) const
    in (privkey.length == 32)
    do {
        pragma(msg, "fixme(cbr): privkey must be scrambled");
        tweak_privkey = privkey.dup;
        ubyte* _privkey = tweak_privkey.ptr;
        const(ubyte)* _tweak = tweak.ptr;

        int ret = secp256k1_ec_seckey_tweak_add(_ctx, _privkey, _tweak);
        check(ret == 1, ConsensusFailCode.SECURITY_PRIVATE_KEY_TWEAK_ADD_FAULT);
    }

    /++
     + libsecp256k1 PubKey Tweak-Add - Tweak pubkey by adding to it
     +
     + @param tweak some bytes to tweak with
     + @param pubkey 32-byte seckey
     +/
    @trusted
    final immutable(ubyte[]) pubTweakAdd(scope const(ubyte[]) pubkey, scope const(ubyte[]) tweak) const
    in (pubkey.length == COMPRESSED_PUBKEY_SIZE)
    in (tweak.length == TWEAK_SIZE)
    do {
        secp256k1_pubkey pubkey_result;
        {
            const ret = secp256k1_ec_pubkey_parse(_ctx, &pubkey_result, &pubkey[0], pubkey.length);
            check(ret == 1, ConsensusFailCode.SECURITY_PUBLIC_KEY_PARSE_FAULT);
        }
        {
            const ret = secp256k1_ec_pubkey_tweak_add(_ctx, &pubkey_result, &tweak[0]);
            check(ret == 1, ConsensusFailCode.SECURITY_PUBLIC_KEY_TWEAK_ADD_FAULT);
        }
        ubyte[COMPRESSED_PUBKEY_SIZE] output_ser;
        enum flag = SECP256K1.EC_COMPRESSED;
        size_t outputLen = output_ser.length;
        {
            const ret = secp256k1_ec_pubkey_serialize(_ctx, &output_ser[0], &outputLen, &pubkey_result, flag);
            assert(outputLen == COMPRESSED_PUBKEY_SIZE);
            check(ret == 1, ConsensusFailCode.SECURITY_PUBLIC_KEY_SERIALIZE);
        }
        return output_ser.idup;
    }

    /++
     + libsecp256k1 PubKey Tweak-Mul - Tweak pubkey by multiplying to it
     +
     + @param tweak some bytes to tweak with
     + @param pubkey 32-byte seckey
     +/
    @trusted
    immutable(ubyte[]) pubTweak(scope const(ubyte[]) pubkey, scope const(ubyte[]) tweak) const
    in (pubkey.length == COMPRESSED_PUBKEY_SIZE)
    in (tweak.length == TWEAK_SIZE)
    do {
        secp256k1_pubkey pubkey_result;
        {
            const ret = secp256k1_ec_pubkey_parse(_ctx, &pubkey_result, &pubkey[0], pubkey.length);
            check(ret == 1, ConsensusFailCode.SECURITY_PUBLIC_KEY_PARSE_FAULT);
        }
        {
            const ret = secp256k1_ec_pubkey_tweak_mul(_ctx, &pubkey_result, &tweak[0]);
            check(ret == 1, ConsensusFailCode.SECURITY_PUBLIC_KEY_TWEAK_MULT_FAULT);
        }
        ubyte[COMPRESSED_PUBKEY_SIZE] output_ser;
        enum flag = SECP256K1.EC_COMPRESSED;
        size_t outputLen = output_ser.length;

        {
            const ret = secp256k1_ec_pubkey_serialize(_ctx, &output_ser[0], &outputLen, &pubkey_result, flag);

            assert(outputLen == COMPRESSED_PUBKEY_SIZE);
            check(ret == 1, ConsensusFailCode.SECURITY_PUBLIC_KEY_SERIALIZE);
        }
        return output_ser.idup;
    }

    alias pubTweakMul = pubTweak;

    /++
     + libsecp256k1 create ECDH secret - constant time ECDH calculation
     +
     + @param seckey byte array of secret key used in exponentiaion
     + @param pubkey byte array of public key used in exponentiaion
     +/
    @trusted
    immutable(ubyte[]) createECDHSecret(
            scope const(ubyte[]) seckey,
    const(ubyte[]) pubkey) const
    in (seckey.length == SECKEY_SIZE)
    in (pubkey.length == COMPRESSED_PUBKEY_SIZE)

    do {
        scope (exit) {
            randomizeContext;
        }
        secp256k1_pubkey pubkey_result;
        ubyte[32] result;
        {
            const ret = secp256k1_ec_pubkey_parse(_ctx, &pubkey_result, &pubkey[0], pubkey.length);
            check(ret == 1, ConsensusFailCode.SECURITY_PUBLIC_KEY_PARSE_FAULT);
        }
        {
            const ret = secp256k1_ecdh(_ctx, &result[0], &pubkey_result, &seckey[0], null, null);
            check(ret == 1, ConsensusFailCode.SECURITY_EDCH_FAULT);
        }
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
}

version (unittest) {
    import tagion.utils.Miscellaneous : toHexString, decode;
    import std.string : representation;

    const(ubyte[]) sha256(scope const(ubyte[]) data) {
        import std.digest.sha : SHA256;
        import std.digest;

        return digest!SHA256(data).dup;
    }
}

unittest { /// Test of ECDSA
    import std.traits;
    import std.stdio;

    /++
 + This tests secret key verify() for a valid secretkey
 +/{
        auto sec = "67E56582298859DDAE725F972992A07C6C4FB9F62A8FFF58CE3CA926A1063530".decode;
        try {
            auto crypt = new NativeSecp256k1ECDSA;
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
        auto sec = "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF".decode;
        try {
            auto crypt = new NativeSecp256k1ECDSA;
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
        auto sec = "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF".decode;
        try {
            auto crypt = new NativeSecp256k1ECDSA;
            auto result = crypt.getPubkey(sec);
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
        const data = "CF80CD8AED482D5D1527D7DC72FCEFF84E6326592848447D2DC0B0E87DFC9A90".decode; //sha256hash of "testing"
        const sec = "67E56582298859DDAE725F972992A07C6C4FB9F62A8FFF58CE3CA926A1063530".decode;
        try {
            const crypt = new NativeSecp256k1ECDSA;
            const result = crypt.sign(data, sec);
            assert(result == "182A108E1448DC8F1FB467D06A0F3BB8EA0533584CB954EF8DA112F1D60E39A21C66F36DA211C087F3AF88B50EDF4F9BDAA6CF5FD6817E74DCA34DB12390C6E9"
                    .decode);
        }
        catch (ConsensusException e) {
            assert(0, e.msg);
        }
    }

    /++
 + This tests sign() for a invalid secretkey
 +/
    {
        const data = "CF80CD8AED482D5D1527D7DC72FCEFF84E6326592848447D2DC0B0E87DFC9A90".decode; //sha256hash of "testing"
        const sec = "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF".decode;
        try {
            const crypt = new NativeSecp256k1ECDSA;
            const result = crypt.sign(data, sec);
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
        const sec = "67E56582298859DDAE725F972992A07C6C4FB9F62A8FFF58CE3CA926A1063530".decode;
        const data = "3982F19BEF1615BCCFBB05E321C10E1D4CBA3DF0E841C2E41EEB6016347653C3".decode; //sha256hash of "tweak"
        try {
            const crypt = new NativeSecp256k1ECDSA;
            ubyte[] result;
            crypt.privTweakAdd(sec, data, result);
            assert(result == "A168571E189E6F9A7E2D657A4B53AE99B909F7E712D1C23CED28093CD57C88F3".decode);
        }
        catch (ConsensusException e) {
            assert(0, e.msg);
        }
    }

    /++
 + This tests private key tweak-mul
 +/
    {
        const sec = "67E56582298859DDAE725F972992A07C6C4FB9F62A8FFF58CE3CA926A1063530".decode;
        const data = "3982F19BEF1615BCCFBB05E321C10E1D4CBA3DF0E841C2E41EEB6016347653C3".decode; //sha256hash of "tweak"
        try {
            const crypt = new NativeSecp256k1ECDSA;
            ubyte[] result;
            crypt.privTweakMul(sec, data, result);
            assert(result == "97F8184235F101550F3C71C927507651BD3F1CDB4A5A33B8986ACF0DEE20FFFC".decode);
        }
        catch (ConsensusException e) {
            assert(0, e.msg);
        }
    }

    /++
 + This tests private key tweak-add uncompressed
 +/
    {
        const pubkey = "033b691036600deb3e04eb666760352989a734c0d24d93630688f1e45ca1b0deb1".decode;
        const tweak = "3982F19BEF1615BCCFBB05E321C10E1D4CBA3DF0E841C2E41EEB6016347653C3".decode; //sha256hash of "tweak"
        try {
            const crypt = new NativeSecp256k1ECDSA;
            const result = crypt.pubTweakAdd(pubkey, tweak);
            assert(result != pubkey);
            assert(result == "0357f2926dd1107f86a3353bc023425c64b5294c70672bd89564a92d79ae128300".decode);
        }
        catch (ConsensusException e) {
            assert(0, e.msg);
        }
    }

    /++
 + This tests private key tweak-mul uncompressed
 +/
    {
        const pubkey = "033b691036600deb3e04eb666760352989a734c0d24d93630688f1e45ca1b0deb1".decode;
        const tweak = "3982F19BEF1615BCCFBB05E321C10E1D4CBA3DF0E841C2E41EEB6016347653C3".decode; //sha256hash of "tweak"
        try {
            const crypt = new NativeSecp256k1ECDSA;
            const result = crypt.pubTweakMul(pubkey, tweak);
            assert(result != pubkey);
            assert(result == "02a80ffb5f6598b3c223e1917c0b3b93a7e7a39bea126c30d3253240b83ed18b57".decode);
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
            auto crypt = new NativeSecp256k1ECDSA;
            auto result = crypt.randomizeContext;
            assert(result);
        }
        catch (ConsensusException e) {
            assert(0, e.msg);
        }
    }

    {
        auto message = "CF80CD8AED482D5D1527D7DC72FCEFF84E6326592848447D2DC0B0E87DFC9A90".decode;
        auto seed = "A441B15FE9A3CF5661190A0B93B9DEC7D04127288CC87250967CF3B52894D110".decode; //sha256hash of "random"
        import tagion.utils.Miscellaneous : toHexString;
        import std.digest.sha;

        try {
            auto crypt = new NativeSecp256k1ECDSA;
            auto data = seed.dup;
            do {
                data = sha256Of(data).dup;
            }
            while (!crypt.secKeyVerify(data));
            immutable privkey = data.idup;
            immutable pubkey = crypt.getPubkey(privkey);
            writefln("pubkey = %(%02x%)", pubkey);
            immutable signature = crypt.sign(message, privkey);
            assert(crypt.verify(message, signature, pubkey));
        }
        catch (ConsensusException e) {
            assert(0, e.msg);
        }

    }

    { //
        const crypt = new NativeSecp256k1ECDSA;
        const sec = "67E56582298859DDAE725F972992A07C6C4FB9F62A8FFF58CE3CA926A1063530".decode;
        immutable privkey = sec.idup;
        //        auto privkey = crypt.secKeyVerify( sec );
        assert(crypt.secKeyVerify(privkey));
        immutable pubkey = crypt.getPubkey(privkey);

        // Message
        const message = "CF80CD8AED482D5D1527D7DC72FCEFF84E6326592848447D2DC0B0E87DFC9A90".decode;
        const signature = crypt.sign(message, privkey);
        assert(crypt.verify(message, signature, pubkey));

        // Drived key a
        const drive = sha256("ABCDEF".decode);
        ubyte[] privkey_a_drived;
        crypt.privTweakMul(privkey, drive, privkey_a_drived);
        assert(privkey != privkey_a_drived);
        const pubkey_a_drived = crypt.pubTweakMul(pubkey, drive);
        assert(pubkey != pubkey_a_drived);
        const signature_a_drived = crypt.sign(message, privkey_a_drived);
        assert(crypt.verify(message, signature_a_drived, pubkey_a_drived));

        // Drive key b from key a
        ubyte[] privkey_b_drived;
        crypt.privTweakMul(privkey_a_drived, drive, privkey_b_drived);
        assert(privkey_b_drived != privkey_a_drived);
        const pubkey_b_drived = crypt.pubTweakMul(pubkey_a_drived, drive);
        assert(pubkey_b_drived != pubkey_a_drived);
        const signature_b_drived = crypt.sign(message, privkey_b_drived);
        assert(crypt.verify(message, signature_b_drived, pubkey_b_drived));

    }

    {
        const crypt = new NativeSecp256k1ECDSA;
        const sec = "67E56582298859DDAE725F972992A07C6C4FB9F62A8FFF58CE3CA926A1063530".decode;
        immutable privkey = sec.idup;
        //        auto privkey = crypt.secKeyVerify( sec );
        assert(crypt.secKeyVerify(privkey));
        immutable pubkey = crypt.getPubkey(privkey);

        // Message
        const message = "CF80CD8AED482D5D1527D7DC72FCEFF84E6326592848447D2DC0B0E87DFC9A90".decode;
        const signature = crypt.sign(message, privkey);
        assert(crypt.verify(message, signature, pubkey));

    }

    {
        const crypt = new NativeSecp256k1ECDSA;
        const sec = "67E56582298859DDAE725F972992A07C6C4FB9F62A8FFF58CE3CA926A1063530".decode;
        immutable privkey = sec.idup;
        assert(crypt.secKeyVerify(privkey));
        immutable pubkey = crypt.getPubkey(privkey);

        // Message
        const message = "CF80CD8AED482D5D1527D7DC72FCEFF84E6326592848447D2DC0B0E87DFC9A90".decode;
        const signature = crypt.sign(message, privkey);
        assert(crypt.verify(message, signature, pubkey));

    }

    {
        const crypt = new NativeSecp256k1ECDSA;
        const sec = "67E56582298859DDAE725F972992A07C6C4FB9F62A8FFF58CE3CA926A1063530".decode;
        immutable privkey = sec.idup;
        //        auto privkey = crypt.secKeyVerify( sec );
        assert(crypt.secKeyVerify(privkey));
        immutable pubkey = crypt.getPubkey(privkey);

        // Message
        const message = "CF80CD8AED482D5D1527D7DC72FCEFF84E6326592848447D2DC0B0E87DFC9A90".decode;
        const signature = crypt.sign(message, privkey);
        assert(crypt.verify(message, signature, pubkey));

    }

    {
        const crypt = new NativeSecp256k1ECDSA;
        const sec = "67E56582298859DDAE725F972992A07C6C4FB9F62A8FFF58CE3CA926A1063530".decode;
        immutable privkey = sec.idup;
        //        auto privkey = crypt.secKeyVerify( sec );
        assert(crypt.secKeyVerify(privkey));
        immutable pubkey = crypt.getPubkey(privkey);

        // Message
        const message = "CF80CD8AED482D5D1527D7DC72FCEFF84E6326592848447D2DC0B0E87DFC9A90".decode;
        const signature = crypt.sign(message, privkey);
        assert(crypt.verify(message, signature, pubkey));

    }

    {
        const crypt = new NativeSecp256k1ECDSA;
        const sec = "67E56582298859DDAE725F972992A07C6C4FB9F62A8FFF58CE3CA926A1063530".decode;
        immutable privkey = sec.idup;
        //        auto privkey = crypt.secKeyVerify( sec );
        assert(crypt.secKeyVerify(privkey));
        immutable pubkey = crypt.getPubkey(privkey);

        // Message
        const message = "CF80CD8AED482D5D1527D7DC72FCEFF84E6326592848447D2DC0B0E87DFC9A90".decode;
        const signature = crypt.sign(message, privkey);

        assert(crypt.verify(message, signature, pubkey));

    }

    //Test ECDH
    {
        import std.stdio;

        const crypt = new NativeSecp256k1ECDSA;

        const aliceSecretKey = "37cf9a0f624a21b0821f4ab3f711ac3a86ac3ae8e4d25bdbd8cdcad7b6cf92d4".decode;
        const alicePublicKey = crypt.getPubkey(aliceSecretKey);

        const bobSecretKey = "2f402cd0753d3afca00bd3f7661ca2f882176ae4135b415efae0e9c616b4a63e".decode;
        const bobPublicKey = crypt.getPubkey(bobSecretKey);

        assert(alicePublicKey == "0251958fb5c78264dc67edec62ad7cb0722ca7468e9781c1aebc0c05c5e8be05da".decode);
        assert(bobPublicKey == "0289685350631b9fee83158aa55980af0969305f698ebe3b9475a36340d0b19967".decode);

        const aliceResult = crypt.createECDHSecret(aliceSecretKey, bobPublicKey);
        const bobResult = crypt.createECDHSecret(bobSecretKey, alicePublicKey);

        assert(aliceResult == bobResult);
    }

}
