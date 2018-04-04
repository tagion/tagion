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

private import tagion.crypto.secp256k1.secp256k1;

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
class NativeSecp256k1 {
    struct Context {
        private secp256k1_context* _ctx;
        this(SECP256K1 flag) {
            _ctx=secp256k1_context_create(cast(uint)flag);
        }
        // Clones the context
        this(ref const(Context) context) {
            _ctx=secp256k1_context_clone(context._ctx);
        }
        ~this() {
            secp256k1_context_destroy(_ctx);
        }
        protected const(secp256k1_context)* ctx() {
            return _ctx;
        }
    }

    static ref Context context_none() {
        auto result=new Context(SECP256K1.CONTEXT_NONE);
        return *result;
    }
    static ref Context context_sign() {
        auto result=new Context(SECP256K1.CONTEXT_SIGN);
        return *result;
    }

    static ref Context context_veryfy() {
        auto result=new Context(SECP256K1.CONTEXT_VERIFY);
        return *result;
    }

    static ref Context context_both() {
        auto result=new Context(SECP256K1.CONTEXT_SIGN | SECP256K1.CONTEXT_VERIFY);
        return *result;
    }

    private static secp256k1_context* getContext() {
        assert(0, "Must be implemented");
    }

    // private static final ReentrantReadWriteLock rwl = new ReentrantReadWriteLock();
    // private static final Lock r = rwl.readLock();
    // private static final Lock w = rwl.writeLock();
    // private static ThreadLocal<ByteBuffer> nativeECDSABuffer = new ThreadLocal<ByteBuffer>();


    /**
     * Verifies the given secp256k1 signature in native code.
     * Calling when enabled == false is undefined (probably library not loaded)
     *
     * @param data The data which was signed, must be exactly 32 bytes
     * @param signature The signature
     * @param pub The public key which did the signing
     */
    static bool verify(immutable(ubyte[]) data, immutable(ubyte[]) signature, immutable(ubyte[]) pub)
        in {
            assert(data.length == 32);
            assert(signature.length <= 520);
            assert(pub.length <= 520);
        }
    body {
        auto ctx=getContext();
        int result;
        immutable(ubyte)* sigdata=signature.ptr;
        auto siglen=data.length;

        secp256k1_ecdsa_signature sig;
        secp256k1_pubkey pubkey;
        result = secp256k1_ecdsa_signature_parse_der(ctx, &sig, sigdata, siglen);
        if ( result ) {
            immutable(ubyte)* pubdata=pub.ptr;
            auto publen=pub.length;
            result = secp256k1_ec_pubkey_parse(ctx, &pubkey, pubdata, publen);
            if ( result ) {
                immutable(ubyte)* msgdata=data.ptr;
                result = secp256k1_ecdsa_verify(ctx, &sig, msgdata, &pubkey);
            }
        }
        return result == 1;
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
    enum SIGNATURE_SIZE=72;
    public static immutable(ubyte[]) sign(immutable(ubyte[]) data, immutable(ubyte[]) sec)
        in {
            assert(data.length == 32);
            assert(sec.length <= 32);
        }
    body {
        auto ctx=getContext();
        immutable(ubyte)* msgdata=data.ptr;
        immutable(ubyte)* secKey=sec.ptr;

        secp256k1_ecdsa_signature[SIGNATURE_SIZE] sig_array;
        secp256k1_ecdsa_signature* sig=sig_array.ptr;

        int ret = secp256k1_ecdsa_sign(ctx, sig, msgdata, secKey, null, null );

        ubyte[SIGNATURE_SIZE] outputSer_array;
        ubyte* outputSer = outputSer_array.ptr;
        size_t outputLen = outputSer_array.length;

        if ( ret ) {
            int ret2=secp256k1_ecdsa_signature_serialize_der(ctx, outputSer, &outputLen, sig);
        }

        immutable(ubyte[]) result=outputSer_array.idup;
        return result;
    }

    /**
     * libsecp256k1 Seckey Verify - returns true if valid, false if invalid
     *
     * @param seckey ECDSA Secret key, 32 bytes
     */
    static bool secKeyVerify(immutable(ubyte[]) seckey)
        in {
            assert(seckey.length == 32);
        }
    body {
        auto ctx=getContext();
        immutable(ubyte)* sec=seckey.ptr;
        return secp256k1_ec_seckey_verify(ctx, sec) == 1;
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
    enum PUBKEY_SIZE=65;
    static immutable(ubyte[]) computePubkey(immutable(ubyte[]) seckey)
        in {
            assert(seckey.length == 32);
        }
    body {
        auto ctx=getContext();
        immutable(ubyte)* sec=seckey.ptr;

        secp256k1_pubkey pubkey;

        int ret = secp256k1_ec_pubkey_create(ctx, &pubkey, sec);

        ubyte[PUBKEY_SIZE] outputSer_array;
        ubyte* outputSer = outputSer_array.ptr;
        size_t outputLen = outputSer_array.length;

        if( ret ) {
            int ret2 = secp256k1_ec_pubkey_serialize(ctx, outputSer, &outputLen, &pubkey, SECP256K1.EC_UNCOMPRESSED );
        }

        immutable(ubyte[]) result = outputSer_array.idup;
        return result;
    }

    /**
     * libsecp256k1 Cleanup - This destroys the secp256k1 context object
     * This should be called at the end of the program for proper cleanup of the context.
     */
    ~this() {
        secp256k1_context_destroy(getContext());
    }


    static secp256k1_context* cloneContext() {
        return secp256k1_context_clone(getContext());
    }

    /**
     * libsecp256k1 PrivKey Tweak-Mul - Tweak privkey by multiplying to it
     *
     * @param tweak some bytes to tweak with
     * @param seckey 32-byte seckey
     */
    static immutable(ubyte[]) privKeyTweakMul(immutable(ubyte[]) privkey, immutable(ubyte[]) tweak)
        in {
            assert(privkey.length == 32);
        }
    body {
        auto ctx=getContext();
        ubyte[] privkey_array=privkey.dup;
        ubyte* _privkey=privkey_array.ptr;
//        immutable(ubyte)* _privkey=privkey.ptr;
        immutable(ubyte)* _tweak=tweak.ptr;

        int ret = secp256k1_ec_privkey_tweak_mul(ctx, _privkey, _tweak);

        immutable(ubyte[]) result=privkey_array.idup;
        return result;
    }

    /**
     * libsecp256k1 PrivKey Tweak-Add - Tweak privkey by adding to it
     *
     * @param tweak some bytes to tweak with
     * @param seckey 32-byte seckey
     */
    static immutable(ubyte[]) privKeyTweakAdd(immutable(ubyte[]) privkey, immutable(ubyte[]) tweak)
        in {
            assert(privkey.length == 32);
        }
    body {
        auto ctx=getContext();
        ubyte[] privkey_array=privkey.dup;
        ubyte* _privkey=privkey_array.ptr;
        immutable(ubyte)* _tweak=tweak.ptr;

        int ret = secp256k1_ec_privkey_tweak_add(ctx, _privkey, _tweak);

        immutable(ubyte[]) result=privkey_array.idup;
        return result;
    }

    /**
     * libsecp256k1 PubKey Tweak-Add - Tweak pubkey by adding to it
     *
     * @param tweak some bytes to tweak with
     * @param pubkey 32-byte seckey
     */
    static immutable(ubyte[]) pubKeyTweakAdd(immutable(ubyte[]) pubkey, immutable(ubyte[]) tweak)
        in {
            assert(pubkey.length == 33 || pubkey.length == 65);
        }
    body {
        auto ctx=getContext();
        ubyte[] pubkey_array=pubkey.dup;
        ubyte* _pubkey=pubkey_array.ptr;
        immutable(ubyte)* _tweak=tweak.ptr;
        size_t publen = pubkey.length;

        secp256k1_pubkey pubkey_result;
        int ret = secp256k1_ec_pubkey_parse(ctx, &pubkey_result, _pubkey, publen);

        if( ret ) {
            ret = secp256k1_ec_pubkey_tweak_add(ctx, &pubkey_result, _tweak);
        }

        ubyte[65] outputSer_array;
        ubyte* outputSer=outputSer_array.ptr;
        size_t outputLen = outputSer_array.length;


        if( ret ) {
            int ret2 = secp256k1_ec_pubkey_serialize(ctx, outputSer, &outputLen, &pubkey_result, SECP256K1.EC_UNCOMPRESSED );
        }

        immutable(ubyte[]) result=outputSer_array.idup;
        return result;
    }

    /**
     * libsecp256k1 PubKey Tweak-Mul - Tweak pubkey by multiplying to it
     *
     * @param tweak some bytes to tweak with
     * @param pubkey 32-byte seckey
     */
    public static immutable(ubyte[]) pubKeyTweakMul(immutable(ubyte[]) pubkey, immutable(ubyte[]) tweak)
        in {
            assert(pubkey.length == 33 || pubkey.length == 65);
        }
    body {
        auto ctx=getContext();
        ubyte[] pubkey_array=pubkey.dup;
        ubyte* _pubkey=pubkey_array.ptr;
        immutable(ubyte)* _tweak=tweak.ptr;
        size_t publen = pubkey.length;

          secp256k1_pubkey pubkey_result;
          int ret = secp256k1_ec_pubkey_parse(ctx, &pubkey_result, _pubkey, publen);

          if ( ret ) {
              ret = secp256k1_ec_pubkey_tweak_mul(ctx, &pubkey_result, _tweak);
          }

          ubyte[65] outputSer_array;
          ubyte* outputSer=outputSer_array.ptr;
          size_t outputLen = outputSer_array.length;

          if( ret ) {
              int ret2 = secp256k1_ec_pubkey_serialize(ctx, outputSer, &outputLen, &pubkey_result, SECP256K1.EC_UNCOMPRESSED );
          }

          immutable(ubyte[]) result=outputSer_array.idup;
          return result;
    }

    /**
     * libsecp256k1 create ECDH secret - constant time ECDH calculation
     *
     * @param seckey byte array of secret key used in exponentiaion
     * @param pubkey byte array of public key used in exponentiaion
     */
    public static immutable(ubyte[]) createECDHSecret(immutable(ubyte[]) seckey, immutable(ubyte[]) pubkey)
        in {
            assert(seckey.length <= 32);
            assert(pubkey.length <= 65);
        }
    body {
        auto ctx=getContext();
        immutable(ubyte)* secdata=seckey.ptr;
        immutable(ubyte)* pubdata=pubkey.ptr;
        size_t publen=pubkey.length;

        secp256k1_pubkey pubkey_result;
        ubyte[32] nonce_res_array;
        ubyte* nonce_res = nonce_res_array.ptr;

        int ret = secp256k1_ec_pubkey_parse(ctx, &pubkey_result, pubdata, publen);

        if (ret) {
            ret = secp256k1_ecdh(ctx, nonce_res, &pubkey_result, secdata);
        }

        immutable(ubyte[]) result=nonce_res_array.idup;
        return result;
    }

    /**
     * libsecp256k1 randomize - updates the context randomization
     *
     * @param seed 32-byte random seed
     */
    public static bool randomize(immutable(ubyte[]) seed)
        in {
            assert(seed.length == 32 || seed is null);
        }
    body {
        auto ctx=getContext();
        immutable(ubyte)* _seed=seed.ptr;
        return secp256k1_context_randomize(ctx, _seed) == 1;
    }

}
