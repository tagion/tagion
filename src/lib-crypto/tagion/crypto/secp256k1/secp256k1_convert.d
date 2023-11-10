module tagion.crypto.secp256k1.secp256k1_convert;

import tagion.crypto.secp256k1.NativeSecp256k1ECDSA;
import tagion.crypto.secp256k1.NativeSecp256k1;
import tagion.crypto.secp256k1.NativeSecp256k1Interface;
import tagion.crypto.secp256k1.c.secp256k1;

version (unittest) {
    import tagion.crypto.secp256k1.c.secp256k1_extrakeys;
}
unittest {
    import std.stdio;
    import tagion.crypto.random.random;

    auto ctx = secp256k1_context_create(SECP256K1.CONTEXT_SIGN | SECP256K1.CONTEXT_VERIFY);
    scope (exit) {
        secp256k1_context_destroy(ctx);
    }
    int pk_key;
    void pubkey_test(const(ubyte[]) seckey) {
        assert(seckey.length == NativeSecp256k1Schnorr.SECKEY_SIZE);
        secp256k1_keypair keypair;
        {
            const ret = secp256k1_keypair_create(ctx, &keypair, &seckey[0]);
            assert(ret == 1, "Failed to create keypair");
        }
        writefln("     keypair = %(%02x%)", keypair.data);
        secp256k1_pubkey pubkey_from_keypair;
        {
            const ret = secp256k1_keypair_pub(ctx, &pubkey_from_keypair, &keypair);
            assert(ret == 1, "Failed to get the pubkey from the keypair");
        }
        writefln("      pubkey = %(%02x%)", pubkey_from_keypair.data);
        secp256k1_xonly_pubkey xonly_pubkey_from_keypair;
        {
            const ret = secp256k1_keypair_xonly_pub(ctx, &xonly_pubkey_from_keypair, &pk_key, &keypair);
            assert(ret == 1, "Failed to get the xonly-pubkey from the keypair");
        }
        writefln("xonly_pubkey = %(%02x%)", xonly_pubkey_from_keypair.data);
        ubyte[NativeSecp256k1Schnorr.XONLY_PUBKEY_SIZE] xonly_pubkey_bytes;
        {
            const ret = secp256k1_xonly_pubkey_serialize(ctx, &xonly_pubkey_bytes[0], &xonly_pubkey_from_keypair);
            assert(ret == 1, "Failed to get the xonly-pubkey byte array from the xonly-pubkey");
        }
        writefln(" xonly_bytes = %(%02x%)", xonly_pubkey_bytes);
        secp256k1_xonly_pubkey xonly_pubkey_from_bytes;
        {
            const ret = secp256k1_xonly_pubkey_parse(ctx, &xonly_pubkey_from_bytes, &xonly_pubkey_bytes[0]);
            assert(ret == 1, "Failed to generate pubkey from xonly-pubkey byte array");
        }
        writefln("       xonly = %(%02x%)", xonly_pubkey_from_bytes.data);
        //writefln("  pk_key     = %d", pk_key);
        secp256k1_pubkey pubkey_from_xonly_pubkey;
{
            const ret = secp256k1_pubkey_from_xonly_pubkey(ctx, &pubkey_from_xonly_pubkey, &xonly_pubkey_from_bytes);
            assert(ret == 1, "Failed to generate the pubkey from xonly_pubkey");
        }
        writefln("  from xonly = %(%02x%)", pubkey_from_xonly_pubkey.data);
    }

    import std.stdio;

    foreach (i; 0 .. 7) {
        ubyte[] secret;
        secret.length = 32;
        getRandom(secret);
        writefln("%d --- --- --- ---", i);
        pubkey_test(secret);
    }
}
