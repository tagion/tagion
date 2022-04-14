module tagion.betterC.wallet.Net;

import tagion.crypto.aes.AESCrypto;
import tagion.crypto.secp256k1.NativeSecp256k1;
import tagion.basic.Basic : Buffer;
import std.format;
import std.string : representation;
private import tagion.crypto.secp256k1.c.secp256k1;
private import tagion.crypto.secp256k1.c.secp256k1_ecdh;
import tagion.betterC.utils.Memory;

import tagion.betterC.hibon.Document;

enum HASH_SIZE = 32;

void scramble(T)(scope ref T[] data, scope const(ubyte[]) xor = null) @safe if (T.sizeof is 1) {
    import std.random;

    auto gen = Mt19937(unpredictableSeed);
    pragma(msg, "Fixme(cbr): replace random with  secp256k1");
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

@trusted immutable(Buffer) rawCalcHash(scope const(ubyte[]) data) {
    import std.digest.sha : SHA256;
    import std.digest;

    return digest!SHA256(data).idup;
}

@trusted immutable(Buffer) calcHash(scope const(ubyte[]) data) {
    version (unittest) {
        assert(!Document(data.idup).isInorder, "calcHash should not be use on a Document use hashOf instead");
    }
    return rawCalcHash(data);
}

@trusted immutable(Buffer) calcHash(scope const(ubyte[]) h1, scope const(ubyte[]) h2)
in {
    assert(h1.length is 0 || h1.length is HASH_SIZE,
            format("h1 is not a valid hash (length=%d should be 0 or %d", h1.length, HASH_SIZE));
    assert(h2.length is 0 || h2.length is HASH_SIZE,
            format("h2 is not a valid hash (length=%d should be 0 or %d", h2.length, HASH_SIZE));
}
out (result) {
    if (h1.length is 0) {
        assert(h2 == result);
    }
    else if (h2.length is 0) {
        assert(h1 == result);
    }
}
do {
    pragma(msg, "dlang: Pre and post condition does not work here");
    assert(h1.length is 0 || h1.length is HASH_SIZE,
            format("h1 is not a valid hash (length=%d should be 0 or %d", h1.length, HASH_SIZE));
    assert(h2.length is 0 || h2.length is HASH_SIZE,
            format("h2 is not a valid hash (length=%d should be 0 or %d", h2.length, HASH_SIZE));
    if (h1.length is 0) {
        return h2.idup;
    }
    if (h2.length is 0) {
        return h1.idup;
    }
    return rawCalcHash(h1 ~ h2);
}

@safe struct SecureNet {
    import tagion.basic.Basic : Pubkey;
    import std.digest.hmac : digestHMAC = HMAC;

    protected NativeSecp256k1 _crypt;

    private Pubkey _pubkey;

    bool secKeyVerify(scope const(ubyte[]) privkey) const {
        return _crypt.secKeyVerify(privkey);
    }

    void createKeyPair(ref ubyte[] privkey)
    in {
        assert(_crypt.secKeyVerify(privkey));
    }
    do {
        import std.digest.sha : SHA256;
        import std.string : representation;

        alias AES = AESCrypto!256;
        _pubkey = _crypt.computePubkey(privkey);
        // Generate scramble key for the private key
        import std.random;

        ubyte[] seed;
        seed.create(32);

        scramble(seed);
        // CBR: Note AES need to be change to beable to handle const keys
        auto aes_key = rawCalcHash(seed).dup;
        scramble(seed);
        auto aes_iv = rawCalcHash(seed)[4 .. 4 + AES.BLOCK_SIZE].dup;

        // Encrypt private key
        // auto encrypted_privkey = new ubyte[privkey.length];
        ubyte[] encrypted_privkey;
        encrypted_privkey.create(privkey.length);
        AES.encrypt(aes_key, aes_iv, privkey, encrypted_privkey);

        AES.encrypt(rawCalcHash(seed), aes_iv, encrypted_privkey, privkey);
        scramble(seed);

        AES.encrypt(aes_key, aes_iv, encrypted_privkey, privkey);

        AES.encrypt(aes_key, aes_iv, privkey, seed);

        AES.encrypt(aes_key, aes_iv, encrypted_privkey, privkey);

        @safe
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
                scramble(seed, aes_key);
                scramble(aes_key, seed);
                scramble(aes_iv);
                AES.encrypt(aes_key, aes_iv, privkey, encrypted_privkey);
                AES.encrypt(rawCalcHash(seed), aes_iv, encrypted_privkey, privkey);
            }
            AES.decrypt(aes_key, aes_iv, encrypted_privkey, privkey);
            dg(privkey);
        }

        immutable(ubyte[]) sign(const(ubyte[]) message) const {
            immutable(ubyte)[] result;
            do_secret_stuff((const(ubyte[]) privkey) { result = _crypt.sign(message, privkey); });
            return result;
        }

        void tweakMul(const(ubyte[]) tweak_code, ref ubyte[] tweak_privkey) {
            do_secret_stuff((const(ubyte[]) privkey) @safe { _crypt.privKeyTweakMul(privkey, tweak_code, tweak_privkey); });
        }

        void tweakAdd(const(ubyte[]) tweak_code, ref ubyte[] tweak_privkey) {
            do_secret_stuff((const(ubyte[]) privkey) @safe { _crypt.privKeyTweakAdd(privkey, tweak_code, tweak_privkey); });
        }

        immutable(ubyte[]) ECDHSecret(scope const(Pubkey) pubkey) const {
            Buffer result;
            do_secret_stuff((const(ubyte[]) privkey) @safe {
                result = _crypt.createECDHSecret(privkey, cast(Buffer) pubkey);
            });
            return result;
        }

        Buffer mask(const(ubyte[]) _mask) const {
            import std.algorithm.iteration : sum;

            Buffer result;
            do_secret_stuff((const(ubyte[]) privkey) @safe {
                import tagion.utils.Miscellaneous : xor;

                auto data = xor(privkey, _mask);
                result = calcHash(calcHash(data));
            });
            return result;
        }
    }

    @trusted immutable(Buffer) HMAC(scope const(ubyte[]) data) const pure {
        import std.exception : assumeUnique;
        import std.digest.sha : SHA256;
        import std.digest.hmac : digestHMAC = HMAC;

        scope hmac = digestHMAC!SHA256(data);
        auto result = hmac.finish.dup;
        return assumeUnique(result);
    }

    @nogc final Pubkey pubkey() pure const nothrow {
        return _pubkey;
    }

    final Buffer hmacPubkey() const {
        return HMAC(cast(Buffer) _pubkey);
    }

    final Pubkey derivePubkey(string tweak_word) const {
        const tweak_code = HMAC(tweak_word.representation);
        return derivePubkey(tweak_code);
    }

    final Pubkey derivePubkey(const(ubyte[]) tweak_code) const {
        Pubkey result;
        const pkey = cast(const(ubyte[])) _pubkey;
        result = _crypt.pubKeyTweakMul(pkey, tweak_code);
        return result;
    }

}
