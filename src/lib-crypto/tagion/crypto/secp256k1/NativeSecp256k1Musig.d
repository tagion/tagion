module tagion.crypto.secp256k1.NativeSecp256k1Musig;
@safe:
import std.string : representation;
import std.range;
import std.algorithm;
import tagion.crypto.secp256k1.NativeSecp256k1;
import tagion.crypto.secp256k1.c.secp256k1_musig;
import tagion.crypto.secp256k1.c.secp256k1;
import tagion.crypto.secp256k1.c.secp256k1_extrakeys;

enum TWEAK_SIZE = 32;
enum MESSAGE_SIZE = 32;
enum SESSION_ID_SIZE = 32;
enum SECNONCE_SIZE = 32;
class NativeSecp256k1Musig : NativeSecp256k1 {

    @trusted
    bool partialSign(
            ref const(secp256k1_musig_keyagg_cache) cache,
            ref secp256k1_musig_partial_sig partial_sig,
            ref secp256k1_musig_secnonce secnonce,
            ref scope const(secp256k1_keypair) keypair,
            ref scope const(secp256k1_musig_session) session) const nothrow {
        const ret = secp256k1_musig_partial_sign(
                _ctx,
                &partial_sig,
                &secnonce,
                &keypair,
                &cache,
                &session);
        return ret != 0;
    }

    @trusted
    bool partialVerify(
            ref const(secp256k1_musig_keyagg_cache) cache,
            ref const(secp256k1_musig_partial_sig) partial_sig,
            ref const(secp256k1_musig_pubnonce) pubnonce,
            ref const(secp256k1_pubkey) pubkey,
            ref const(secp256k1_musig_session) session) const nothrow {
        const ret = secp256k1_musig_partial_sig_verify(
                _ctx,
                &partial_sig,
                &pubnonce,
                &pubkey,
                &cache,
                &session);
        return ret != 0;
    }

    /**
    This function is if only the aggregated pubkey is need and no signing
*/
    @trusted
    bool musigPubkeyAggregated(
            ref secp256k1_xonly_pubkey pubkey_agg,
            const(secp256k1_pubkey[]) pubkeys) const {
        const _pubkeys = pubkeys.map!((ref pkey) => &pkey).array;
        const ret = secp256k1_musig_pubkey_agg(
                _ctx,
                null,
                &pubkey_agg,
                null,
                &_pubkeys[0],
                pubkeys.length);
        return ret != 0;

    }

    /**
    Ditto except that it produce a cache which can be used for musig signing
*/
    @trusted
    bool musigPubkeyAggregated(
            ref secp256k1_musig_keyagg_cache cache,
            ref secp256k1_xonly_pubkey pubkey_agg,
            const(secp256k1_pubkey[]) pubkeys) const {
        const _pubkeys = pubkeys.map!((ref pkey) => &pkey).array;
        const ret = secp256k1_musig_pubkey_agg(
                _ctx,
                null,
                &pubkey_agg,
                &cache,
                &_pubkeys[0],
                pubkeys.length);
        return ret != 0;

    }

    @trusted
    bool musigPubkeyTweakAdd(
            ref secp256k1_musig_keyagg_cache cache,
            const(ubyte[]) tweak,
    scope secp256k1_pubkey* output_pubkey = null
    ) const nothrow
    in (tweak.length == TWEAK_SIZE)
    do {
        const ret = secp256k1_musig_pubkey_ec_tweak_add(
                _ctx,
                output_pubkey,
                &cache,
                &tweak[0]);
        return ret != 0;

    }

    @trusted
    bool musigXonlyPubkeyTweakAdd(
            ref secp256k1_musig_keyagg_cache cache,
            const(ubyte[]) tweak,
    scope secp256k1_pubkey* output_pubkey = null) const nothrow
    in (tweak.length == TWEAK_SIZE)
    do {
        const ret = secp256k1_musig_pubkey_xonly_tweak_add(
                _ctx,
                output_pubkey,
                &cache,
                &tweak[0]);
        return ret != 0;

    }

    @trusted
    bool musigNonceGen(
            ref secp256k1_musig_secnonce secnonce,
            ref secp256k1_musig_pubnonce pubnonce,
            ref scope const(secp256k1_pubkey) pubkey,
            scope const(ubyte[]) msg,
    const(ubyte[]) session_id,
    const(ubyte[]) seckey = null) const nothrow
    in (session_id.length == SESSION_ID_SIZE)
    in (msg.length == MESSAGE_SIZE)
    in (seckey.length == SECKEY_SIZE || seckey.length == 0)
    do {
        const(ubyte)* _seckey;
        if (!seckey.empty) {
            _seckey = &seckey[0];
        }
        const ret = secp256k1_musig_nonce_gen(
                _ctx,
                &secnonce,
                &pubnonce,
                &session_id[0],
                _seckey,
                &pubkey,
                &msg[0],
                null,
                null);
        return ret != 0;

    }

    @trusted
    bool musigNonceAgg(
            ref secp256k1_musig_aggnonce aggnonce,
            scope const(secp256k1_musig_pubnonce[]) pubnonces) const nothrow {
        const _pubnonces = pubnonces.map!((ref pnonce) => &pnonce).array;
        const ret = secp256k1_musig_nonce_agg(
                _ctx,
                &aggnonce,
                &_pubnonces[0],
                pubnonces.length);
        return ret != 0;
    }

    @trusted
    bool musigNonceProcess(
            ref secp256k1_musig_session session,
            ref scope const(secp256k1_musig_aggnonce) aggnonce,
            const(ubyte[]) msg,
    const(secp256k1_musig_keyagg_cache) cache) const nothrow
    in (msg.length == MESSAGE_SIZE)
    do {
        const ret = secp256k1_musig_nonce_process(
                _ctx,
                &session,
                &aggnonce,
                &msg[0],
                &cache,
                null);

        return ret != 0;
    }

    /* 
    @trusted 
    void tweak(ref secp256k1_xonly_pubkey pubkey,  
    //  @trusted
  */
}

version (unittest) {

    struct Signer {
        secp256k1_pubkey pubkey;
        secp256k1_musig_pubnonce pubnonce;
        secp256k1_musig_partial_sig partial_sig;
    }

    struct SignerSecret {
        secp256k1_keypair keypair;
        secp256k1_musig_secnonce secnonce;
    }

    import std.algorithm;
    import std.range;
    import std.array;
    import std.format;
    import std.stdio;
}

unittest {
    enum num_of_signers = 4;
    //
    // Generate a list of messages for the sign/verify test
    //
    const message_samples = iota(3)
        .map!(index => format("message %d", index))
        .map!(text => text.representation)
        .map!(buf => sha256(buf))
        .array;
    //
    // This of secret passphrases use to generate keypairs
    //
    const secret_passphrases = iota(num_of_signers)
        .map!(index => format("very secret word %d", index))
        .map!(text => text.representation)
        .map!(buf => sha256(buf))
        .array;
    //
    // Create the keypairs
    //
    const crypt = new NativeSecp256k1Musig;
    //
    // Set the secret for each signer  
    //
    SignerSecret[] signer_secrets;
    signer_secrets.length = secret_passphrases.length;
    //     secp256k1_keypair[] keypairs;
    //   keypairs.length = secret_passphrases.length;
    foreach (i, secret; secret_passphrases) {
        crypt.createKeyPair(secret, signer_secrets[i].keypair);
    }
    Signer[] signers;
    // Extracted the pubkeys
    signers.length = secret_passphrases.length;
    iota(secret_passphrases.length)
        .each!((i) => crypt.getPubkey(signer_secrets[i].keypair, signers[i].pubkey));
    const pubkeys = signers.map!((signer) => signer.pubkey).array;
    //
    // Aggregated common pubkey
    //
    secp256k1_musig_keyagg_cache cache;
    secp256k1_xonly_pubkey agg_pubkey;
    {
        const ret = crypt.musigPubkeyAggregated(cache, agg_pubkey, pubkeys);
        writefln("Agg pubkey %(%02x%)", agg_pubkey.data);
        writefln("ret=%s", ret);
        assert(ret, "Could not aggregated the pubkeys");
    }
    //
    // Signers informations 
    //
    const plain_tweak = sha256("plain text tweak".representation);
    const xonly_tweak = sha256("xonly tweak".representation);

    //
    // Plain text tweak can be use for BIP32 
    // Note. The aggregated pubkey is stored in the chache
    //
    {
        const ret = crypt.musigPubkeyTweakAdd(cache, plain_tweak);
        assert(ret, "Tweak of the pubkey failed");
    }
    //
    // Tweak again with and produce an xonly-pubkey
    //
    secp256k1_pubkey tweaked_pubkey;
    {
        const ret = crypt.musigXonlyPubkeyTweakAdd(cache, xonly_tweak, &tweaked_pubkey);
        assert(ret, "Tweak of the pubkey failed");
    }
    secp256k1_xonly_pubkey tweaked_xonly_pubkey;
    {
        const ret = crypt.xonlyPubkey(tweaked_pubkey, tweaked_xonly_pubkey);
        assert(ret, "Could not produce xonly pubkey");
        writefln("xonly_pubkey=%(%02x%)", tweaked_xonly_pubkey.data);
    }

    //
    // Generate nonce session id (Should only be used one in the unittest it's fixed)
    //
    const session_ids = iota(secret_passphrases.length)
        .map!(index => format("Session id nonce %d", index))
        .map!(text => text.representation)
        .map!(buf => sha256(buf))
        .array;

    //
    // Initialize sessions and nonces for all signers
    // This process should be done by each signer seperately 
    // 
    //const ret=iota(secret_passphrases.length)
    //.all!((i) => crypt.musigNonceGen(secret_s
    // Signer[] signers;
    // signers.length = secret_passphrases.length;

}
