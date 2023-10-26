module tagion.crypto.secp256k1.NativeMusig;
@safe:
import std.string : representation;
import tagion.crypto.secp256k1.NativeSecp256k1;
import tagion.crypto.secp256k1.c.secp256k1_musig;
import tagion.crypto.secp256k1.c.secp256k1;
import tagion.crypto.secp256k1.c.secp256k1_extrakeys;

enum TWEAK_SIZE = 32;
struct NativeMusig {
    const NativeSecp256k1 crypt;
    const ubyte[TWEAK_SIZE] xonly_tweak;
    const ubyte[TWEAK_SIZE] plain_tweak;
    @disable this();
    this(const NativeSecp256k1 crypt, string plain_tweak, string xonly_tweak)
    in (plain_tweak.length <= TWEAK_SIZE)
    in (xonly_tweak.length <= TWEAK_SIZE)
    do {
        this.crypt = crypt;
        this.plain_tweak[0 .. plain_tweak.length] = plain_tweak.representation;
        this.xonly_tweak[0 .. xonly_tweak.length] = xonly_tweak.representation;
    }

    secp256k1_musig_keyagg_cache cache;
    secp256k1_xonly_pubkey agg_pk;
    @trusted
    bool tweak() {
        secp256k1_pubkey output_pk;
        {
            const ret =
                secp256k1_musig_pubkey_ec_tweak_add(crypt._ctx, null, &cache, &plain_tweak[0]);
            if (!ret)
                return false;
        }
        {
            const ret = secp256k1_musig_pubkey_xonly_tweak_add(crypt._ctx, &output_pk, &cache, &xonly_tweak[0]);
            if (!ret)
                return false;
        }
        {
            const ret = secp256k1_xonly_pubkey_from_pubkey(crypt._ctx, &agg_pk, null, &output_pk);
            if (!ret)
                return false;
        }
        return true;
    }
}

version (unittest) {
    import std.algorithm;
    import std.range;
    import std.array;
    import std.format;

    struct Signer {
        secp256k1_pubkey pubkey;
        secp256k1_musig_pubnonce pubnonce;
        secp256k1_musig_partial_sig partial_sig;
    }

}
unittest {
    enum num_of_signers = 4;
    const secret_passphrases = iota(num_of_signers)
        .map!(index => format("very secret word %d", index))
        .map!(text => text.representation)
        .map!(buf => sha256(buf))
        .array;

    //
    // Create the keypairs
    //
    NativeSecp256k1[] crypts = iota(secret_passphrases.length)
        .map!(index => new NativeSecp256k1)
        .array;
    ubyte[][] keypairs;
    keypairs.length = crypts.length;
    foreach (i, crypt, secret; zip(crypts, secret_passphrases).enumerate) {
        crypt.createKeyPair(secret, keypairs[i]);
    }
    //
    const message_samples = iota(3)
        .map!(index => format("message %d", index))
        .map!(text => text.representation)
        .map!(buf => sha256(buf))
        .array;
    //
    // Generate nonce session id
    //
    const session_ids = iota(crypts.length)
        .map!(index => format("Session id nonce %d", index))
        .map!(text => text.representation)
        .map!(buf => sha256(buf))
        .array;
    //
    // 
    //
    Signer[] signers;
    signers.length = crypts.length;

}
