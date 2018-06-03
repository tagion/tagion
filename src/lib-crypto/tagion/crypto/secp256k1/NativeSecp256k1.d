module tagion.crypto.secp256k1.NativeSecp256k1;
/*
 * Copyright 2013 Google Inc.
 * Copyright 2014-2016 the libsecp256k1 contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import std.stdio;

private import tagion.crypto.secp256k1.secp256k1;
import tagion.hashgraph.ConsensusExceptions;

/**
 * <p>This class holds native methods to handle ECDSA verification.</p>
 *
 * <p>You can find an example library that can be used for this at https://github.com/bitcoin/secp256k1</p>
 *
 * <p>To build secp256k1 for use with bitcoinj, run
 * `./configure --enable-jni --enable-experimental --enable-module-ecdh`
 * and `make` then copy `.libs/libsecp256k1.so` to your system library path
 * or point the JVM to the folder containing it with -Djava.library.path
 * </p>
 */
@safe
class NativeSecp256k1 {
    @safe
    static void check(bool flag, ConsensusFailCode code, string file = __FILE__, size_t line = __LINE__) {
        if (!flag) {
            throw new SecurityConsensusException(code, file, line);
        }
    }
    enum DER_SIGNATURE_SIZE=72;
    enum SIGNATURE_SIZE=64;

    // struct Context {
    //     private secp256k1_context* _ctx;
    //     @trusted
    //     this(SECP256K1 flag) {
    //         _ctx=secp256k1_context_create(cast(uint)flag);
    //     }
    //     // Clones the context

    //     @trusted
    //     this(ref const(Context) context) {
    //         _ctx=secp256k1_context_clone(context._ctx);
    //     }

    //     @trusted
    //     ~this() {
    //         secp256k1_context_destroy(_ctx);
    //     }
    //     protected const(secp256k1_context)* ctx() {
    //         return _ctx;
    //     }
    // }

    // static ref Context context_none() {
    //     auto result=new Context(SECP256K1.CONTEXT_NONE);
    //     return *result;
    // }

    // static ref Context context_sign() {
    //     auto result=new Context(SECP256K1.CONTEXT_SIGN);
    //     return *result;
    // }

    // static ref Context context_verify() {
    //     auto result=new Context(SECP256K1.CONTEXT_VERIFY);
    //     return *result;
    // }

    // static ref Context context_both() {
    //     auto result=new Context(SECP256K1.CONTEXT_SIGN | SECP256K1.CONTEXT_VERIFY);
    //     return *result;
    // }

    private secp256k1_context* _ctx;

    private bool _DER_format;
    @trusted
    this(const bool DER_format=false, const SECP256K1 flag=SECP256K1.CONTEXT_SIGN | SECP256K1.CONTEXT_VERIFY) {
        _ctx = secp256k1_context_create(flag);
        _DER_format=DER_format;
    }


    // private static secp256k1_context* getContext() {
    //     return _ctx;
    // }

    /**
     * Verifies the given secp256k1 signature in native code.
     * Calling when enabled == false is undefined (probably library not loaded)
     *
     * @param data The data which was signed, must be exactly 32 bytes
     * @param signature The signature
     * @param pub The public key which did the signing
     */
    @trusted
    bool verify(immutable(ubyte[]) data, immutable(ubyte[]) signature, const(ubyte[]) pub)
        in {
            assert(data.length == 32);
            assert(signature.length <= 520);
            assert(pub.length <= 520);
        }
    body {
//        auto ctx=getContext();
        int ret;
        immutable(ubyte)* sigdata=signature.ptr;
        auto siglen=signature.length;
        const(ubyte)* pubdata=pub.ptr;
        immutable(ubyte)* msgdata=data.ptr;

        secp256k1_ecdsa_signature sig;
        secp256k1_pubkey pubkey;
        if ( _DER_format ) {
            ret = secp256k1_ecdsa_signature_parse_der(_ctx, &sig, sigdata, siglen);
            check(ret == 1, ConsensusFailCode.SECURITY_DER_SIGNATURE_PARSE_FAULT);
        }
        else {
            check(siglen == SIGNATURE_SIZE, ConsensusFailCode.SECURITY_SIGNATURE_SIZE_FAULT);
            import core.stdc.string : memcpy;
            memcpy(&(sig.data), sigdata,  siglen);
        }
        auto publen=pub.length;
        ret = secp256k1_ec_pubkey_parse(_ctx, &pubkey, pubdata, publen);
        check(ret == 1, ConsensusFailCode.SECURITY_PUBLIC_KEY_PARSE_FAULT);

        ret = secp256k1_ecdsa_verify(_ctx, &sig, msgdata, &pubkey);
        return ret == 1;
    }

    /**
     * libsecp256k1 Create an ECDSA signature.
     *
     * @param data Message hash, 32 bytes
     * @param key Secret key, 32 bytes
     *
     * Return values
     * @param sig byte array of signature
     */
    @trusted
    immutable(ubyte[]) sign(immutable(ubyte[]) data, const(ubyte[]) sec)
        in {
            assert(data.length == 32);
            assert(sec.length <= 32);
        }
    body {
        immutable(ubyte)* msgdata=data.ptr;
        const(ubyte)*     secKey=sec.ptr;
        secp256k1_ecdsa_signature sig_array;
        secp256k1_ecdsa_signature* sig=&sig_array;

        int ret = secp256k1_ecdsa_sign(_ctx, sig, msgdata, secKey, null, null );
        check(ret == 1, ConsensusFailCode.SECURITY_SIGN_FAULT);

        if ( _DER_format ) {
            ubyte[DER_SIGNATURE_SIZE] outputSer_array;
            ubyte* outputSer = outputSer_array.ptr;
            size_t outputLen = outputSer_array.length;
            int ret2=secp256k1_ecdsa_signature_serialize_der(_ctx, outputSer, &outputLen, sig);
            immutable(ubyte[]) result=outputSer_array[0..outputLen].idup;

            return result;
        }
        else {
            immutable(ubyte[]) result=(sig.data.ptr)[0..SIGNATURE_SIZE].idup;
            return result;
        }
    }

    /**
     * libsecp256k1 Seckey Verify - returns true if valid, false if invalid
     *
     * @param seckey ECDSA Secret key, 32 bytes
     */
    @trusted
    bool secKeyVerify(const(ubyte[]) seckey)
        in {
            assert(seckey.length == 32);
        }
    body {
        const(ubyte)* sec=seckey.ptr;
        return secp256k1_ec_seckey_verify(_ctx, sec) == 1;
    }


    /**
     * libsecp256k1 Compute Pubkey - computes public key from secret key
     *
     * @param seckey ECDSA Secret key, 32 bytes
     *
     * Return values
     * @param pubkey ECDSA Public key, 33 or 65 bytes
     */
    //TODO add a 'compressed' arg
    enum UNCOMPRESSED_PUBKEY_SIZE=65;
    enum COMPRESSED_PUBKEY_SIZE=33;
    @trusted
    immutable(ubyte[]) computePubkey(const(ubyte[]) seckey, immutable bool compress=true)
        in {
            assert(seckey.length == 32);
        }
    out(result) {
        if ( compress ) {
            assert(result.length == COMPRESSED_PUBKEY_SIZE);
        }
        else {
            assert(result.length == UNCOMPRESSED_PUBKEY_SIZE);
        }
    }
    body {
//        auto ctx=getContext();
        const(ubyte)* sec=seckey.ptr;

        secp256k1_pubkey pubkey;

        int ret = secp256k1_ec_pubkey_create(_ctx, &pubkey, sec);
        check(ret == 1, ConsensusFailCode.SECURITY_PUBLIC_KEY_CREATE_FAULT);
        // ubyte[pubkey_size] outputSer_array;
        ubyte[] outputSer_array;
        SECP256K1 flag;
        if ( compress ) {
            outputSer_array=new ubyte[COMPRESSED_PUBKEY_SIZE];
            flag=SECP256K1.EC_COMPRESSED;
        }
        else {
            outputSer_array=new ubyte[UNCOMPRESSED_PUBKEY_SIZE];
            flag=SECP256K1.EC_UNCOMPRESSED;
        }
        ubyte* outputSer = outputSer_array.ptr;
        size_t outputLen = outputSer_array.length;

        int ret2 = secp256k1_ec_pubkey_serialize(_ctx, outputSer, &outputLen, &pubkey, flag );

        immutable(ubyte[]) result = outputSer_array[0..outputLen].idup;
        return result;
    }

    /**
     * libsecp256k1 Cleanup - This destroys the secp256k1 context object
     * This should be called at the end of the program for proper cleanup of the context.
     */
    @trusted
    ~this() {
        secp256k1_context_destroy(_ctx);
    }

    @trusted
    secp256k1_context* cloneContext() {
        return secp256k1_context_clone(_ctx);
    }

    /**
     * libsecp256k1 PrivKey Tweak-Mul - Tweak privkey by multiplying to it
     *
     * @param tweak some bytes to tweak with
     * @param seckey 32-byte seckey
     */
    @trusted
    immutable(ubyte[]) privKeyTweakMul(immutable(ubyte[]) privkey, immutable(ubyte[]) tweak)
        in {
            assert(privkey.length == 32);
        }
    body {
//        auto ctx=getContext();
        ubyte[] privkey_array=privkey.dup;
        ubyte* _privkey=privkey_array.ptr;
//        immutable(ubyte)* _privkey=privkey.ptr;
        immutable(ubyte)* _tweak=tweak.ptr;

        int ret = secp256k1_ec_privkey_tweak_mul(_ctx, _privkey, _tweak);
        check(ret == 1, ConsensusFailCode.SECURITY_PRIVATE_KEY_TWEAK_MULT_FAULT);

        immutable(ubyte[]) result=privkey_array.idup;
        return result;
    }

    /**
     * libsecp256k1 PrivKey Tweak-Add - Tweak privkey by adding to it
     *
     * @param tweak some bytes to tweak with
     * @param seckey 32-byte seckey
     */
    @trusted
    immutable(ubyte[]) privKeyTweakAdd(immutable(ubyte[]) privkey, immutable(ubyte[]) tweak)
        in {
            assert(privkey.length == 32);
        }
    body {
//        auto ctx=getContext();
        ubyte[] privkey_array=privkey.dup;
        ubyte* _privkey=privkey_array.ptr;
        immutable(ubyte)* _tweak=tweak.ptr;

        int ret = secp256k1_ec_privkey_tweak_add(_ctx, _privkey, _tweak);
        check(ret == 1, ConsensusFailCode.SECURITY_PRIVATE_KEY_TWEAK_ADD_FAULT);
        immutable(ubyte[]) result=privkey_array.idup;
        return result;
    }

    /**
     * libsecp256k1 PubKey Tweak-Add - Tweak pubkey by adding to it
     *
     * @param tweak some bytes to tweak with
     * @param pubkey 32-byte seckey
     */
    @trusted
    immutable(ubyte[]) pubKeyTweakAdd(immutable(ubyte[]) pubkey, immutable(ubyte[]) tweak, immutable bool compress=true) {
        if ( compress ) {
            check(pubkey.length == COMPRESSED_PUBKEY_SIZE, ConsensusFailCode.SECURITY_PUBLIC_KEY_COMPRESS_SIZE_FAULT );
        }
        else {
            check(pubkey.length == UNCOMPRESSED_PUBKEY_SIZE, ConsensusFailCode.SECURITY_PUBLIC_KEY_UNCOMPRESS_SIZE_FAULT );
        }
//        auto ctx=getContext();
        ubyte[] pubkey_array=pubkey.dup;
        ubyte* _pubkey=pubkey_array.ptr;
        immutable(ubyte)* _tweak=tweak.ptr;
        size_t publen = pubkey.length;

        secp256k1_pubkey pubkey_result;
        int ret = secp256k1_ec_pubkey_parse(_ctx, &pubkey_result, _pubkey, publen);
        check(ret == 1, ConsensusFailCode.SECURITY_PUBLIC_KEY_PARSE_FAULT);

        ret = secp256k1_ec_pubkey_tweak_add(_ctx, &pubkey_result, _tweak);
        check(ret == 1, ConsensusFailCode.SECURITY_PUBLIC_KEY_TWEAK_ADD_FAULT);


        ubyte[] outputSer_array;
        SECP256K1 flag;
        if ( compress ) {
            outputSer_array=new ubyte[COMPRESSED_PUBKEY_SIZE];
            flag=SECP256K1.EC_COMPRESSED;
        }
        else {
            outputSer_array=new ubyte[UNCOMPRESSED_PUBKEY_SIZE];
            flag=SECP256K1.EC_UNCOMPRESSED;
        }

        ubyte* outputSer=outputSer_array.ptr;
        size_t outputLen = outputSer_array.length;


        int ret2 = secp256k1_ec_pubkey_serialize(_ctx, outputSer, &outputLen, &pubkey_result, flag );

        immutable(ubyte[]) result=outputSer_array.idup;
        return result;
    }

    /**
     * libsecp256k1 PubKey Tweak-Mul - Tweak pubkey by multiplying to it
     *
     * @param tweak some bytes to tweak with
     * @param pubkey 32-byte seckey
     */
    @trusted
    immutable(ubyte[]) pubKeyTweakMul(immutable(ubyte[]) pubkey, immutable(ubyte[]) tweak, immutable bool compress=true)
        in {
            assert(pubkey.length == 33 || pubkey.length == 65);
        }
    body {
//        auto ctx=getContext();
        ubyte[] pubkey_array=pubkey.dup;
        ubyte* _pubkey=pubkey_array.ptr;
        immutable(ubyte)* _tweak=tweak.ptr;
        size_t publen = pubkey.length;

        secp256k1_pubkey pubkey_result;
        int ret = secp256k1_ec_pubkey_parse(_ctx, &pubkey_result, _pubkey, publen);
        check(ret == 1, ConsensusFailCode.SECURITY_PUBLIC_KEY_PARSE_FAULT);

        ret = secp256k1_ec_pubkey_tweak_mul(_ctx, &pubkey_result, _tweak);
        check(ret == 1, ConsensusFailCode.SECURITY_PUBLIC_KEY_TWEAK_MULT_FAULT);

        ubyte[] outputSer_array;
        SECP256K1 flag;
        if ( compress ) {
            outputSer_array=new ubyte[COMPRESSED_PUBKEY_SIZE];
            flag=SECP256K1.EC_COMPRESSED;
        }
        else {
            outputSer_array=new ubyte[UNCOMPRESSED_PUBKEY_SIZE];
            flag=SECP256K1.EC_UNCOMPRESSED;
        }

        ubyte* outputSer=outputSer_array.ptr;
        size_t outputLen = outputSer_array.length;

        int ret2 = secp256k1_ec_pubkey_serialize(_ctx, outputSer, &outputLen, &pubkey_result, flag );

        immutable(ubyte[]) result=outputSer_array.idup;
        return result;
    }

    /**
     * libsecp256k1 create ECDH secret - constant time ECDH calculation
     *
     * @param seckey byte array of secret key used in exponentiaion
     * @param pubkey byte array of public key used in exponentiaion
     */
    @trusted
    version(none)
    immutable(ubyte[]) createECDHSecret(immutable(ubyte[]) seckey, immutable(ubyte[]) pubkey)
        in {
            assert(seckey.length <= 32);
            assert(pubkey.length <= 65);
        }
    body {
//        auto ctx=getContext();
        immutable(ubyte)* secdata=seckey.ptr;
        immutable(ubyte)* pubdata=pubkey.ptr;
        size_t publen=pubkey.length;

        secp256k1_pubkey pubkey_result;
        ubyte[32] nonce_res_array;
        ubyte* nonce_res = nonce_res_array.ptr;

        int ret = secp256k1_ec_pubkey_parse(_ctx, &pubkey_result, pubdata, publen);
        check(ret == 1, ConsensusFailCode.SECURITY_PUBLIC_KEY_PARSE_FAULT);

        if (ret) {
            ret = secp256k1_ecdh(_ctx, nonce_res, &pubkey_result, secdata);
        }

        immutable(ubyte[]) result=nonce_res_array.idup;
        return result;
    }

    /**
     * libsecp256k1 randomize - updates the context randomization
     *
     * @param seed 32-byte random seed
     */
    @trusted
    bool randomize(immutable(ubyte[]) seed)
        in {
            assert(seed.length == 32 || seed is null);
        }
    body {
//        auto ctx=getContext();
        immutable(ubyte)* _seed=seed.ptr;
        return secp256k1_context_randomize(_ctx, _seed) == 1;
    }


}

@safe
unittest {
    import tagion.crypto.Hash : toHexString, decode;
    import std.traits;
    import std.stdio;
/*
 * This tests verify() for a valid signature
 */
    {
        auto data = decode("CF80CD8AED482D5D1527D7DC72FCEFF84E6326592848447D2DC0B0E87DFC9A90"); //sha256hash of "testing"
        auto sig = decode("3044022079BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F817980220294F14E883B3F525B5367756C2A11EF6CF84B730B36C17CB0C56F0AAB2C98589");
        auto pub = decode("040A629506E1B65CD9D2E0BA9C75DF9C4FED0DB16DC9625ED14397F0AFC836FAE595DC53F8B0EFE61E703075BD9B143BAC75EC0E19F82A2208CAEB32BE53414C40");
        try {
            auto crypt = new NativeSecp256k1(true);
            auto result = crypt.verify( data, sig, pub);
            assert(result);
        }
        catch ( ConsensusException e ) {
            assert(0, e.toText);
        }
    }

/**
 * This tests verify() for a non-valid signature
 */
    {
        auto data = decode("CF80CD8AED482D5D1527D7DC72FCEFF84E6326592848447D2DC0B0E87DFC9A91"); //sha256hash of "testing"
        auto sig = decode("3044022079BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F817980220294F14E883B3F525B5367756C2A11EF6CF84B730B36C17CB0C56F0AAB2C98589");
        auto pub = decode("040A629506E1B65CD9D2E0BA9C75DF9C4FED0DB16DC9625ED14397F0AFC836FAE595DC53F8B0EFE61E703075BD9B143BAC75EC0E19F82A2208CAEB32BE53414C40");
        try {
            auto crypt = new NativeSecp256k1(true);
            auto result = crypt.verify( data, sig, pub);
            assert(!result);
        }
        catch ( ConsensusException e ) {
            assert(0, e.toText);
        }
    }

/**
 * This tests secret key verify() for a valid secretkey
 */
    {
        auto sec = decode("67E56582298859DDAE725F972992A07C6C4FB9F62A8FFF58CE3CA926A1063530");
        try {
            auto crypt = new NativeSecp256k1(true);
            auto result = crypt.secKeyVerify( sec );
            assert(result);
        }
        catch ( ConsensusException e ) {
            assert(0, e.toText);
        }
    }

/**
 * This tests secret key verify() for an invalid secretkey
 */
    {
        auto sec = decode("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF");
        try {
            auto crypt = new NativeSecp256k1;
            auto result = crypt.secKeyVerify( sec );
            assert(!result);
        }
        catch ( ConsensusException e ) {
            assert(0, e.toText);
        }
    }

/**
 * This tests public key create() for a invalid secretkey
 */
    {
        auto sec = decode("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF");
        try {
            auto crypt = new NativeSecp256k1(true);
            auto resultArr = crypt.computePubkey(sec);
            assert(0, "This test should throw an ConsensusException");
        }
        catch ( ConsensusException e ) {
            assert(e.code == ConsensusFailCode.SECURITY_PUBLIC_KEY_CREATE_FAULT);
            // auto pubkeyString = resultArr.toHexString!true;
            // assert( pubkeyString == "0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000");
        }

    }

/**
 * This tests sign() for a valid secretkey
 */
    {
        auto data = decode("CF80CD8AED482D5D1527D7DC72FCEFF84E6326592848447D2DC0B0E87DFC9A90"); //sha256hash of "testing"
        auto sec = decode("67E56582298859DDAE725F972992A07C6C4FB9F62A8FFF58CE3CA926A1063530");
        try {
            auto crypt = new NativeSecp256k1(true);
            auto resultArr = crypt.sign(data, sec);
            auto sigString = resultArr.toHexString!true;
            assert( sigString == "30440220182A108E1448DC8F1FB467D06A0F3BB8EA0533584CB954EF8DA112F1D60E39A202201C66F36DA211C087F3AF88B50EDF4F9BDAA6CF5FD6817E74DCA34DB12390C6E9" );
        }
        catch ( ConsensusException e ) {
            assert(0, e.toText);
        }
    }

/**
 * This tests sign() for a invalid secretkey
 */
    {
        auto data = decode("CF80CD8AED482D5D1527D7DC72FCEFF84E6326592848447D2DC0B0E87DFC9A90"); //sha256hash of "testing"
        auto sec = decode("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF");
        try {
            auto crypt = new NativeSecp256k1(true);
            auto resultArr = crypt.sign(data, sec);
            assert(0, "This test should throw an ConsensusException");
        }
        catch ( ConsensusException e ) {
            assert(e.code == ConsensusFailCode.SECURITY_SIGN_FAULT);
        }
    }

/**
 * This tests private key tweak-add
 */
    {
        auto sec = decode("67E56582298859DDAE725F972992A07C6C4FB9F62A8FFF58CE3CA926A1063530");
        auto data = decode("3982F19BEF1615BCCFBB05E321C10E1D4CBA3DF0E841C2E41EEB6016347653C3"); //sha256hash of "tweak"
        try {
            auto crypt = new NativeSecp256k1(true);
            auto resultArr = crypt.privKeyTweakAdd( sec , data );
            auto sigString = resultArr.toHexString!true;
            assert( sigString == "A168571E189E6F9A7E2D657A4B53AE99B909F7E712D1C23CED28093CD57C88F3" );
        }
        catch ( ConsensusException e ) {
            assert(0, e.toText);
        }
    }

/**
 * This tests private key tweak-mul
 */
    {
        auto sec = decode("67E56582298859DDAE725F972992A07C6C4FB9F62A8FFF58CE3CA926A1063530");
        auto data = decode("3982F19BEF1615BCCFBB05E321C10E1D4CBA3DF0E841C2E41EEB6016347653C3"); //sha256hash of "tweak"
        try {
            auto crypt = new NativeSecp256k1(true);
            auto resultArr = crypt.privKeyTweakMul( sec , data );
            auto sigString = resultArr.toHexString!true;
            assert( sigString == "97F8184235F101550F3C71C927507651BD3F1CDB4A5A33B8986ACF0DEE20FFFC" );
        }
        catch ( ConsensusException e ) {
            assert(0, e.toText);
        }
    }

/**
 * This tests private key tweak-add uncompressed
 */
    {
        auto pub = decode("040A629506E1B65CD9D2E0BA9C75DF9C4FED0DB16DC9625ED14397F0AFC836FAE595DC53F8B0EFE61E703075BD9B143BAC75EC0E19F82A2208CAEB32BE53414C40");
        auto data = decode("3982F19BEF1615BCCFBB05E321C10E1D4CBA3DF0E841C2E41EEB6016347653C3"); //sha256hash of "tweak"
        try {
            auto crypt = new NativeSecp256k1(true);
            auto resultArr = crypt.pubKeyTweakAdd(pub , data, false);
            auto sigString = resultArr.toHexString!true;
            assert( sigString == "0411C6790F4B663CCE607BAAE08C43557EDC1A4D11D88DFCB3D841D0C6A941AF525A268E2A863C148555C48FB5FBA368E88718A46E205FABC3DBA2CCFFAB0796EF" );
        }
        catch ( ConsensusException e ) {
            assert(0, e.toText);
        }
    }

/**
 * This tests private key tweak-mul uncompressed
 */
    {
        auto pub = decode("040A629506E1B65CD9D2E0BA9C75DF9C4FED0DB16DC9625ED14397F0AFC836FAE595DC53F8B0EFE61E703075BD9B143BAC75EC0E19F82A2208CAEB32BE53414C40");
        auto data = decode("3982F19BEF1615BCCFBB05E321C10E1D4CBA3DF0E841C2E41EEB6016347653C3"); //sha256hash of "tweak"
        try {
            auto crypt = new NativeSecp256k1(true);
            auto resultArr = crypt.pubKeyTweakMul(pub , data, false);
            auto sigString = resultArr.toHexString!true;
            assert( sigString == "04E0FE6FE55EBCA626B98A807F6CAF654139E14E5E3698F01A9A658E21DC1D2791EC060D4F412A794D5370F672BC94B722640B5F76914151CFCA6E712CA48CC589" );
        }
        catch ( ConsensusException e ) {
            assert(0, e.toText);
        }
    }

/**
 * This tests seed randomization
 */
    {
        auto seed = decode("A441B15FE9A3CF5661190A0B93B9DEC7D04127288CC87250967CF3B52894D110"); //sha256hash of "random"
        try {
            auto crypt = new NativeSecp256k1(true);
            auto result = crypt.randomize(seed);
            assert( result );
        }
        catch ( ConsensusException e ) {
            assert(0, e.toText);
        }
    }

    {
        auto message= decode("CF80CD8AED482D5D1527D7DC72FCEFF84E6326592848447D2DC0B0E87DFC9A90");
        //auto message= decode("CF80CD8AED482D5D1527D7DC72FCEFF84E6326592848447D2DC0B0E87DFC9A9A");
        auto seed = decode("A441B15FE9A3CF5661190A0B93B9DEC7D04127288CC87250967CF3B52894D110"); //sha256hash of "random"
        import tagion.crypto.Hash : toHexString;
        import std.digest.sha;
        try {
            auto crypt=new NativeSecp256k1;
            auto data=seed.dup;
            do {
                data=sha256Of(data).dup;
            } while (!crypt.secKeyVerify(data));
            immutable privkey=data.idup;
            immutable pubkey=crypt.computePubkey(privkey);

            immutable signature=crypt.sign(message, privkey);
            assert(crypt.verify( message, signature, pubkey));
        }
        catch ( ConsensusException e ) {
            assert(0, e.toText);
        }

    }
    //Test ECDH
    version(none)
    {
        auto sec = decode("67E56582298859DDAE725F972992A07C6C4FB9F62A8FFF58CE3CA926A1063530");
        auto pub = decode("040A629506E1B65CD9D2E0BA9C75DF9C4FED0DB16DC9625ED14397F0AFC836FAE595DC53F8B0EFE61E703075BD9B143BAC75EC0E19F82A2208CAEB32BE53414C40");

        auto resultArr = Crypt.createECDHSecret(sec, pub);
        auto ecdhString = resultArr.toHexString;
        assert( ecdhString == "2A2A67007A926E6594AF3EB564FC74005B37A9C8AEF2033C4552051B5C87F043" );
    }

}
