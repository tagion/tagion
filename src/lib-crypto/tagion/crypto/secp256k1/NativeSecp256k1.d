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
import tagion.crypto.random.random;
import tagion.crypto.secp256k1.NativeSecp256k1Interface;
import std.exception : assumeUnique;
import tagion.basic.ConsensusExceptions;

import tagion.utils.Miscellaneous : toHexString;
import std.algorithm;
import std.array;

enum Schnorr = true;
//alias NativeSecp256k1EDCSA = NativeSecp256k1T!false;
alias NativeSecp256k1Schnorr = NativeSecp256k1;
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
class NativeSecp256k1 : NativeSecp256k1Interface {
    static void check(bool flag, ConsensusFailCode code, string file = __FILE__, size_t line = __LINE__) pure {
        if (!flag) {
            throw new SecurityConsensusException(code, file, line);
        }
    }

    enum TWEAK_SIZE = 32;
    enum SIGNATURE_SIZE = 64;
    enum SECKEY_SIZE = 32;
    enum XONLY_PUBKEY_SIZE = 32;
    enum MESSAGE_SIZE = 32;
    enum KEYPAIR_SIZE = secp256k1_keypair.data.length;

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
    static if (!Schnorr)
        final bool verify(const(ubyte[]) msg, const(ubyte[]) signature, const(ubyte[]) pub) const
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
    static if (!Schnorr)
        immutable(ubyte[]) sign(const(ubyte[]) msg, const(ubyte[]) seckey) const
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
    static if (!Schnorr)
        final bool secKeyVerify(scope const(ubyte[]) seckey) const nothrow @nogc
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
    enum COMPRESSED_PUBKEY_SIZE = 33;
    @trusted
    static if (!Schnorr)
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
    static if (!Schnorr)
        final void privTweakMul(
                const(ubyte[]) privkey,
    const(ubyte[]) tweak,
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

    static if (!Schnorr)
        alias privTweak = privTweakMul;
    /++
     + libsecp256k1 PrivKey Tweak-Add - Tweak privkey by adding to it
     +
     + @param tweak some bytes to tweak with
     + @param seckey 32-byte seckey
     +/
    @trusted
    static if (!Schnorr)
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
    static if (!Schnorr)
        final immutable(ubyte[]) pubTweakAdd(
            const(ubyte[]) pubkey,
    const(ubyte[]) tweak) const
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
    static if (!Schnorr)
        final immutable(ubyte[]) pubTweakMul(const(ubyte[]) pubkey, const(ubyte[]) tweak) const
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

    static if (!Schnorr)
        alias pubTweak = pubTweakMul;

    @trusted
    static if (Schnorr)
        final void privTweak(
                scope const(ubyte[]) keypair,
    scope const(ubyte[]) tweak,
    out ubyte[] tweakked_keypair) const
    in (keypair.length == secp256k1_keypair.data.length)
    in (tweak.length == TWEAK_SIZE)
    do {
        scope (exit) {
            randomizeContext;
        }
        static assert(secp256k1_keypair.data.offsetof == 0);
        tweakked_keypair = keypair.dup;
        auto _keypair = cast(secp256k1_keypair*)(&tweakked_keypair[0]);
        {
            const ret = secp256k1_keypair_xonly_tweak_add(_ctx, _keypair, &tweak[0]);
            check(ret == 1, ConsensusFailCode.SECURITY_PUBLIC_KEY_TWEAK_MULT_FAULT);
        }

    }

    @trusted
    static if (Schnorr)
        final immutable(ubyte[]) pubTweak(scope const(ubyte[]) pubkey, scope const(ubyte[]) tweak) const
    in (pubkey.length == XONLY_PUBKEY_SIZE)
    in (tweak.length == TWEAK_SIZE)
    do {
        secp256k1_xonly_pubkey xonly_pubkey;
        {
            const ret = secp256k1_xonly_pubkey_parse(_ctx, &xonly_pubkey, &pubkey[0]);
            check(ret == 1, ConsensusFailCode.SECURITY_PUBLIC_KEY_SERIALIZE);
        }
        secp256k1_pubkey output_pubkey;
        {
            const ret = secp256k1_xonly_pubkey_tweak_add(_ctx, &output_pubkey, &xonly_pubkey, &tweak[0]);
            check(ret == 1, ConsensusFailCode.SECURITY_PUBLIC_KEY_TWEAK_MULT_FAULT);

        }
        secp256k1_xonly_pubkey _xonly_pubkey;
        {
            const ret = secp256k1_xonly_pubkey_from_pubkey(_ctx, &_xonly_pubkey, null, &output_pubkey);
            check(ret == 1, ConsensusFailCode.SECURITY_PUBLIC_KEY_PARSE_FAULT);
        }
        ubyte[XONLY_PUBKEY_SIZE] pubkey_result;

        {
            const ret = secp256k1_xonly_pubkey_serialize(_ctx, &pubkey_result[0], &_xonly_pubkey);
            check(ret == 1, ConsensusFailCode.SECURITY_PUBLIC_KEY_PARSE_FAULT);

        }

        return pubkey_result.idup;
    }
    /++
     + libsecp256k1 create ECDH secret - constant time ECDH calculation
     +
     + @param seckey byte array of secret key used in exponentiaion
     + @param pubkey byte array of public key used in exponentiaion
     +/
    static if (!Schnorr)
        @trusted
        final immutable(ubyte[]) createECDHSecret(
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

    @trusted
    static if (Schnorr)
        final immutable(ubyte[]) createECDHSecret(
            scope const(ubyte[]) keypair,
    const(ubyte[]) pubkey) const
    in (keypair.length == secp256k1_keypair.data.length)
    in (pubkey.length == XONLY_PUBKEY_SIZE)
    do {
        scope (exit) {
            randomizeContext;
        }
        secp256k1_pubkey pubkey_result;
        {

            // const ret = secp256k1_keypair_xonly_pub(_ctx, 
        }
        return null;
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

    @trusted
    static if (Schnorr)
        final void createKeyPair(
                scope const(ubyte[]) seckey,
    ref secp256k1_keypair keypair) const
    in (seckey.length == SECKEY_SIZE)

    do {
        scope (exit) {
            randomizeContext;
        }
        const rt = secp256k1_keypair_create(_ctx, &keypair, &seckey[0]);
        check(rt == 1, ConsensusFailCode.SECURITY_FAILD_TO_CREATE_KEYPAIR);

    }

    @trusted
    static if (Schnorr)
        final void createKeyPair(
                const(ubyte[]) seckey,
    out ubyte[] keypair) const
    in (seckey.length == SECKEY_SIZE)
    do {
        keypair.length = secp256k1_keypair.data.length;
        auto _keypair = cast(secp256k1_keypair*)(&keypair[0]);
        createKeyPair(seckey, *_keypair);
    }

    @trusted
    static if (Schnorr)
        final void getSecretKey(
                ref scope const(ubyte[]) keypair,
    out ubyte[] seckey) nothrow const
    in (keypair.length == secp256k1_keypair.data.length)

    do {
        seckey.length = SECKEY_SIZE;
        const _keypair = cast(secp256k1_keypair*)&keypair[0];
        const ret = secp256k1_keypair_sec(_ctx, &seckey[0], _keypair);
        assert(ret is 1);
    }

    @trusted
    static if (Schnorr)
        final void getPubkey(
                ref scope const(secp256k1_keypair) keypair,
                ref scope secp256k1_pubkey pubkey) const nothrow {
            secp256k1_keypair_pub(_ctx, &pubkey, &keypair);
        }

    /**
       Takes both a seckey and keypair 
*/
    @trusted
    static if (Schnorr)
        final immutable(ubyte[]) getPubkey(scope const(ubyte[]) keypair_seckey) const
    in (keypair_seckey.length == secp256k1_keypair.data.length ||
            keypair_seckey.length == SECKEY_SIZE)

    do {
        static assert(secp256k1_keypair.data.offsetof == 0);
        if (keypair_seckey.length == SECKEY_SIZE) {
            secp256k1_keypair tmp_keypair;
            scope (exit) {
                tmp_keypair.data[] = 0;
            }
            createKeyPair(keypair_seckey, tmp_keypair);
            return getPubkey(tmp_keypair);

        }
        const _keypair = cast(secp256k1_keypair*)(&keypair_seckey[0]);
        return getPubkey(*_keypair);
    }

    @trusted
    static if (Schnorr)
        final immutable(ubyte[]) getPubkey(ref scope const(secp256k1_keypair) keypair) const {
        secp256k1_xonly_pubkey xonly_pubkey;
        {
            const rt = secp256k1_keypair_xonly_pub(_ctx, &xonly_pubkey, null, &keypair);
            check(rt == 1, ConsensusFailCode.SECURITY_FAILD_PUBKEY_FROM_KEYPAIR);
        }
        ubyte[XONLY_PUBKEY_SIZE] pubkey;
        {
            const rt = secp256k1_xonly_pubkey_serialize(_ctx, &pubkey[0], &xonly_pubkey);
            check(rt == 1, ConsensusFailCode.SECURITY_FAILD_PUBKEY_FROM_KEYPAIR);
        }
        return pubkey.idup;

    }

    @trusted
    static if (Schnorr)
        final immutable(ubyte[]) sign(
            const(ubyte[]) msg,
    ref scope const(secp256k1_keypair) keypair,
    scope const(ubyte[]) aux_random) const
    in (msg.length == MESSAGE_SIZE)
    in (aux_random.length == MESSAGE_SIZE || aux_random.length == 0)

    do {
        scope (exit) {
            randomizeContext;
        }
        ubyte[SIGNATURE_SIZE] signature;
        const rt = secp256k1_schnorrsig_sign32(_ctx, &signature[0], &msg[0], &keypair, &aux_random[0]);
        check(rt == 1, ConsensusFailCode.SECURITY_FAILD_TO_SIGN_MESSAGE);
        return signature.idup;
    }

    @trusted
    static if (Schnorr)
        final immutable(ubyte[]) sign(
            const(ubyte[]) msg,
    scope const(ubyte[]) keypair,
    scope const(ubyte[]) aux_random) const
    in (keypair.length == secp256k1_keypair.data.length)
    do {
        const _keypair = cast(secp256k1_keypair*)(&keypair[0]);
        return sign(msg, *_keypair, aux_random);
    }

    static if (Schnorr)
        final immutable(ubyte[]) sign(
            const(ubyte[]) msg,
    scope const(ubyte[]) keypair) const {
        ubyte[MESSAGE_SIZE] _aux_random;
        ubyte[] aux_random = _aux_random;
        getRandom(aux_random);
        return sign(msg, keypair, aux_random);
    }

    @trusted
    static if (Schnorr)
        final bool verify(
                const(ubyte[]) msg,
    const(ubyte[]) signature,
    const(ubyte[]) pubkey) const nothrow
    in (pubkey.length == XONLY_PUBKEY_SIZE)

    do {
        secp256k1_xonly_pubkey xonly_pubkey;
        secp256k1_xonly_pubkey_parse(_ctx, &xonly_pubkey, &pubkey[0]);
        return verify(signature, msg, xonly_pubkey);
    }

    @trusted
    static if (Schnorr)
        final bool verify(
                const(ubyte[]) signature,
    const(ubyte[]) msg,
    ref scope const(secp256k1_xonly_pubkey) xonly_pubkey) const nothrow
    in (signature.length == SIGNATURE_SIZE)
    in (msg.length == MESSAGE_SIZE)

    do {
        const ret = secp256k1_schnorrsig_verify(_ctx, &signature[0], &msg[0], MESSAGE_SIZE, &xonly_pubkey);
        return ret != 0;

    }

    @trusted
    static if (Schnorr)
        final bool xonlyPubkey(
                ref scope const(secp256k1_pubkey) pubkey,
                ref secp256k1_xonly_pubkey xonly_pubkey) const nothrow @nogc {
            const ret = secp256k1_xonly_pubkey_from_pubkey(_ctx, &xonly_pubkey, null, &pubkey);
            return ret != 0;
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

unittest { /// Schnorr test generated from the secp256k1/examples/schnorr.c 
    const aux_random = "b0d8d9a460ddcea7ae5dc37a1b5511eb2ab829abe9f2999e490beba20ff3509a".decode;
    const msg_hash = "1bd69c075dd7b78c4f20a698b22a3fb9d7461525c39827d6aaf7a1628be0a283".decode;
    const secret_key = "e46b4b2b99674889342c851f890862264a872d4ac53a039fbdab91fd68ed4e71".decode;
    const expected_pubkey = "ecd21d66cf97843d467c9d02c5781ec1ec2b369620605fd847bd23472afc7e74".decode;
    const expected_signature = "021e9a32a12ead3144bb230a81794913a856296ed369159d01b8f57d6d7e7d3630e34f84d49ec054d5251ff6539f24b21097a9c39329eaab2e9429147d6d82f8"
        .decode;
    const expected_keypair = decode("e46b4b2b99674889342c851f890862264a872d4ac53a039fbdab91fd68ed4e71747efc2a4723bd47d85f602096362becc11e78c5029d7c463d8497cf661dd2eca89c1820ccc2dd9b0e0e5ab13b1454eb3c37c31308ae20dd8d2aca2199ff4e6b");
    auto crypt = new NativeSecp256k1Schnorr;
    //secp256k1_keypair keypair;
    ubyte[] keypair;
    crypt.createKeyPair(secret_key, keypair);
    //writefln("keypair %(%02x%)", keypair);
    assert(keypair == expected_keypair);
    const signature = crypt.sign(msg_hash, keypair, aux_random);
    assert(signature == expected_signature);
    //writefln("expected_pubkey %(%02x%)", expected_pubkey);
    const pubkey = crypt.getPubkey(keypair); //writefln("         pubkey %(%02x%)", pubkey);
    assert(pubkey == expected_pubkey);
    const signature_ok = crypt.verify(msg_hash, signature, pubkey);
    assert(signature_ok, "Schnorr signing failded");
}

unittest { /// Schnorr tweak
    const aux_random = "b0d8d9a460ddcea7ae5dc37a1b5511eb2ab829abe9f2999e490beba20ff3509a".decode;
    const msg_hash = "1bd69c075dd7b78c4f20a698b22a3fb9d7461525c39827d6aaf7a1628be0a283".decode;
    const secret_key = "e46b4b2b99674889342c851f890862264a872d4ac53a039fbdab91fd68ed4e71".decode;
    auto crypt = new NativeSecp256k1Schnorr;
    //secp256k1_keypair keypair;
    ubyte[] keypair;
    crypt.createKeyPair(secret_key, keypair);

    const pubkey = crypt.getPubkey(keypair);
    const tweak = sha256("Some tweak".representation);
    ubyte[] tweakked_keypair;
    crypt.privTweak(keypair, tweak, tweakked_keypair);
    assert(tweakked_keypair != keypair);
    const tweakked_pubkey = crypt.pubTweak(pubkey, tweak);

    assert(tweakked_pubkey != pubkey);

    const tweakked_pubkey_from_keypair = crypt.getPubkey(tweakked_keypair);
    assert(tweakked_pubkey == tweakked_pubkey_from_keypair, "The tweakked pubkey should be the same as the keypair tweakked pubkey");

    const signature = crypt.sign(msg_hash, keypair, aux_random);
    const tweakked_signature = crypt.sign(msg_hash, tweakked_keypair, aux_random);

    assert(signature != tweakked_signature, "The signature and the tweakked signature should not be the same");
    {
        const tweakked_signature_ok = crypt.verify(msg_hash, tweakked_signature, tweakked_pubkey);
        assert(tweakked_signature, "Tweakked signature should be correct");
    }
    {
        const signature_not_ok = crypt.verify(msg_hash, tweakked_signature, pubkey);
        assert(!signature_not_ok, "None tweakked signature should not be correct");
    }
    {
        const signature_not_ok = crypt.verify(msg_hash, signature, tweakked_pubkey);
        assert(!signature_not_ok, "None tweakked signature should not be correct");
    }
}
