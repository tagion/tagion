module tagion.crypto.secp256k1.NativeSecp256k1Musig;
@safe:
import std.algorithm;
import std.range;
import std.string : representation;
import tagion.crypto.secp256k1.NativeSecp256k1;
import tagion.crypto.secp256k1.c.secp256k1_musig;
import tagion.crypto.secp256k1.c.secp256k1;
import tagion.crypto.secp256k1.c.secp256k1_extrakeys;
import tagion.crypto.secp256k1.NativeSecp256k1Interface;
immutable(ubyte[]) SECP256K1_SCHNORRSIG_EXTRAPARAMS_MAGIC = [ 0xda, 0x6f, 0xb3, 0x8c ];

void partial_sig_from_sig(ref secp256k1_musig_partial_sig partial_sig, const(ubyte[]) signature) nothrow 
in(signature.length==32)
do {
    partial_sig.data[0..SECP256K1_SCHNORRSIG_EXTRAPARAMS_MAGIC.length]=SECP256K1_SCHNORRSIG_EXTRAPARAMS_MAGIC;
    partial_sig.data[SECP256K1_SCHNORRSIG_EXTRAPARAMS_MAGIC.length..$]=signature;
}

class NativeSecp256k1Musig : NativeSecp256k1Schnorr {
    enum SESSION_ID_SIZE = 32;
    enum SECNONCE_SIZE = 32;

    @trusted
    bool musigPartialSign(
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

    @trusted
    bool musigSignAgg(
            out ubyte[] signature,
            ref scope const(secp256k1_musig_partial_sig[]) partial_sig,
    ref scope const(secp256k1_musig_session) session) const nothrow {
        signature.length = SIGNATURE_SIZE;
        const _partial_sig = partial_sig.map!((ref psig) => &psig).array;
        const ret = secp256k1_musig_partial_sig_agg(
                _ctx,
                &signature[0],
                &session,
                &_partial_sig[0],
                partial_sig.length);
        return ret != 0;
    }

    /**
    This function is if only the aggregated pubkey is need and no signing
*/
    @trusted
    bool musigPubkeyAggregated(
            ref secp256k1_pubkey pubkey_agg,
            scope const(secp256k1_pubkey[]) pubkeys) const nothrow {
        secp256k1_musig_keyagg_cache cache;
        secp256k1_xonly_pubkey xonly_pubkey;
        const _pubkeys = pubkeys.map!((ref pkey) => &pkey).array;
        int ret = secp256k1_musig_pubkey_agg(
                _ctx,
                null,
                &xonly_pubkey,
                &cache,
                &_pubkeys[0],
                pubkeys.length);
        if (ret) {
            ret = secp256k1_musig_pubkey_get(
                    _ctx,
                    &pubkey_agg,
                    &cache);
        }
        return ret != 0;

    }

    @trusted 
    immutable(ubyte[]) signatureAggregate(const(ubyte[][]) signatures) const 
in(signatures.all!(sig => sig.length == SIGNATURE_SIZE))
do
    {
      
    secp256k1_musig_session session;
        int nonce_parity;
        if( secp256k1_musig_nonce_parity(
            _ctx,
            &nonce_parity,
            &session) == 0) {
            return null;
        }
       
        secp256k1_musig_partial_sig[] partial_sigs;
        partial_sigs.length=signatures.length;
        iota(signatures.length)
        .each!((index) => 
        partial_sig_from_sig(partial_sigs[index], signatures[index]));
        auto _partial_sigs=partial_sigs.map!((ref sig) => &sig).array; 
        ubyte[SIGNATURE_SIZE] signature;
        if (secp256k1_musig_partial_sig_agg(
            _ctx,
            &signature[0],
            &session,
            &_partial_sigs[0],
            partial_sigs.length) == 0) {
        return null;    
        }
        return signature.idup;
    }
    @trusted
    immutable(ubyte[]) pubkeyAggregate(const(ubyte[][]) pubkeys) const
    
    do {
        secp256k1_pubkey[] _pubkeys;
        _pubkeys.length = pubkeys.length;
        foreach (ref pkey, pkey_input; lockstep(_pubkeys, pubkeys)) {
            if (secp256k1_ec_pubkey_parse(_ctx, &pkey, &pkey_input[0], pkey_input.length) == 0) {
                return null;
            }

        }
        secp256k1_musig_keyagg_cache cache;
        secp256k1_pubkey pubkey_agg;
        if (musigPubkeyAggregated(cache, pubkey_agg, _pubkeys) == 0) {
            return null;
        }
        ubyte[PUBKEY_SIZE] result;
        size_t len = PUBKEY_SIZE;
        if (secp256k1_ec_pubkey_serialize(_ctx, &result[0], &len, &pubkey_agg, SECP256K1.EC_COMPRESSED) == 0) {
            return null;
        }
        return result.idup;
    }

         
    /**
    Ditto except that it produce a cache which can be used for musig signing
*/
    @trusted
    bool musigPubkeyAggregated(
            ref secp256k1_musig_keyagg_cache cache,
            ref secp256k1_pubkey pubkey_agg,
            const(secp256k1_pubkey[]) pubkeys) const {
        const _pubkeys = pubkeys.map!((ref pkey) => &pkey).array;
        int ret = secp256k1_musig_pubkey_agg(
                _ctx,
                null,
                null,
                &cache,
                &_pubkeys[0],
                pubkeys.length);
        if (ret != 0) {
            ret = secp256k1_musig_pubkey_get(_ctx, &pubkey_agg, &cache);
        }
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
    import std.array;
    import std.format;
    import std.range;
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
        .map!(buf => buf.sha256)
        .array;
    //
    // This of secret passphrases use to generate keypairs
    //
    const secret_passphrases = iota(num_of_signers)
        .map!(index => format("very secret word %d", index))
        .map!(text => text.representation)
        .map!(buf => buf.sha256)
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
    secp256k1_pubkey agg_pubkey;
    {
        const ret = crypt.musigPubkeyAggregated(cache, agg_pubkey, pubkeys);
        writefln("Agg pubkey %(%02x%)", agg_pubkey.data);
        writefln("ret=%s", ret);
        assert(ret, "Could not aggregated the pubkeys");
    }
    version (none) {
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
        //
        // secp256k1_xonly_pubkey tweaked_xonly_pubkey;
        //    
        {
            const ret = crypt.xonlyPubkey(tweaked_pubkey, agg_pubkey);
            assert(ret, "Could not produce xonly pubkey");
        }
        writefln("xonly_pubkey=%(%02x%)", agg_pubkey.data);
    }
    //
    // Generate nonce session id (Should only be used one in the unittest it's fixed)
    //
    const session_ids = iota(secret_passphrases.length)
        .map!(index => format("Session id nonce %d", index))
        .map!(text => text.representation)
        .map!(buf => buf.sha256)
        .array;

    //
    // Initialize sessions and nonces for all signers
    // This process should be done by each signer seperately 
    //
    {
        const ret = iota(secret_passphrases.length)
            .all!((i) => crypt.musigNonceGen(
                    signer_secrets[i].secnonce,
                    signers[i].pubnonce,
                    signers[i].pubkey,
                    message_samples[0],
                    session_ids[i]));
        assert(ret, "Failed in generating musig nonce");
    }

    //
    // Each signer sends the pubnonces to each other in the first Round
    const pubnonces = signers.map!(signer => signer.pubnonce).array;
    // Each signer generates a aggregated pubnouce
    secp256k1_musig_aggnonce agg_pubnonce;
    {
        const ret = crypt.musigNonceAgg(agg_pubnonce, pubnonces);
        assert(ret, "Failed to generates aggregated pubnonce from pubnonces");
    }
    //
    // Aggregate all nonces of all signers to a single nonce
    //
    secp256k1_musig_session session;
    {
        const ret = crypt.musigNonceProcess(session, agg_pubnonce, message_samples[0], cache);
        assert(ret, "Failed to aggregated all signers nonces");
    }

    //
    // Each signer can produces a partial signature
    //
    {
        const ret = iota(secret_passphrases.length)
            .all!((i) => crypt.musigPartialSign(
                    cache,
                    signers[i].partial_sig,
                    signer_secrets[i].secnonce,
                    signer_secrets[i].keypair,
                    session));

        assert(ret, "Failed to partial sign aggregated message");
    }
    //
    // The signature can be verified individually (Informations for the Second round)
    //
    {
        const ret = signers
            .all!((signer) => crypt.partialVerify(
                    cache,
                    signer.partial_sig,
                    signer.pubnonce,
                    signer.pubkey,
                    session));
        assert(ret, "Failed to partial verify the signatures");
    }

    //
    // Produce musig from the partial signatures
    //
    const partial_sigs = signers.map!(signer => signer.partial_sig).array;
    ubyte[] signature;
    {
        const ret = crypt.musigSignAgg(signature, partial_sigs, session);
        assert(ret, "Failed to aggregated sign");
    }

    //
    // Verify signature
    //
    {
        const ret = crypt.verify(signature, message_samples[0], agg_pubkey);
        assert(ret, "Failed to verify multi signature");
    }
}

unittest { /// Simple musig sign
    import std.algorithm;
    import std.array;
    import std.format;
    import std.range;
    import std.stdio;

    const msg = "Message to be signed".representation.sha256;
    enum number_of_signers = 4;
    auto index_range = iota(number_of_signers);
    const secrets = index_range.map!(index => format("Secret %d", index).representation.sha256).array;
    auto crypt = new NativeSecp256k1Musig;
    secp256k1_keypair[] keypairs;
    secp256k1_pubkey[] pubkeys;
    pubkeys.length = keypairs.length = secrets.length;
    index_range
        .each!(index => crypt.createKeyPair(secrets[index], keypairs[index]));

    index_range
        .each!(index => crypt.getPubkey(keypairs[index], pubkeys[index]));

    pubkeys.each!(pubkey => writefln("%(%02x%)", pubkey.data));

    foreach (number_of_participants; iota(2, number_of_signers + 1)) {
        writefln("number_of_participants=%s", number_of_participants);
        secp256k1_musig_keyagg_cache cache;
        secp256k1_pubkey agg_pubkey;
        {
            const ret = crypt.musigPubkeyAggregated(cache, agg_pubkey, pubkeys[0 .. number_of_participants]);
            assert(ret, "Failed to aggregate the public keys");
        }
        secp256k1_musig_session session;
        //const _s=   format("Some random nonce %s", number_of_participants)
        //.representation.sha256;
        secp256k1_musig_partial_sig[] partial_signatures;
        secp256k1_musig_secnonce[] secnonces;
        secnonces.length = partial_signatures.length = number_of_participants;

        version (none) {
            const ret = iota(number_of_participants)
                .map!((index) => crypt.musigPartialSign(
                        cache,
                        partial_signatures[index],
                        secnonces[index],
                        keypairs[index],
                        session))
                .all!((ret) => ret != 0);

        }
        {
            ubyte[] signature;
            //     const ret=crypt.musigSignAgg(signature
        }

    }

}
