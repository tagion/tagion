module tagion.crypto.SecureInterfaceNet;

import std.typecons : TypedefType;
import tagion.basic.Types : Buffer, isBufferType;
import tagion.crypto.Types : Pubkey, Signature, Fingerprint;

import tagion.hibon.HiBONRecord : isHiBONRecord, HiBONPrefix;
import tagion.hibon.Document : Document;

import tagion.basic.ConsensusExceptions : Check, SecurityConsensusException, ConsensusFailCode;

alias check = Check!SecurityConsensusException;

@safe
interface HashNet {
    uint hashSize() const pure nothrow;

    final Fingerprint calcHash(B)(scope const(B) data) const
    if (isBufferType!B) {
        return Fingerprint(rawCalcHash(cast(TypedefType!B) data));
    }

    immutable(Buffer) rawCalcHash(scope const(ubyte[]) data) const;
    immutable(Buffer) HMAC(scope const(ubyte[]) data) const pure;
    /++
     Hash used for Merkle tree
     +/
    immutable(Buffer) binaryHash(scope const(ubyte[]) h1, scope const(ubyte[]) h2) const;

    final immutable(Buffer) binaryHash(B)(scope const(B) h1, scope const(B) h2) const
    if (isBufferType!B) {
        return binaryHash(cast(TypedefType!B) h1, cast(TypedefType!B) h2);
    }

    Fingerprint calcHash(const(Document) doc) const;

    final Fingerprint calcHash(T)(T value) const if (isHiBONRecord!T) {
        return calcHash(value.toDoc);
    }

    string multihash() const pure nothrow;
}

@safe
interface SecureNet : HashNet {
    import std.typecons : Tuple;

    alias Signed = Tuple!(Signature, "signature", Fingerprint, "message");
    @nogc Pubkey pubkey() pure const nothrow;
    bool verify(const Fingerprint message, const Signature signature, const Pubkey pubkey) const;
    final bool verify(const Document doc, const Signature signature, const Pubkey pubkey) const {

        

            .check(doc.keys.front[0]!is HiBONPrefix.HASH, ConsensusFailCode
            .SECURITY_MESSAGE_HASH_KEY);
        immutable message = calcHash(doc);
        return verify(message, signature, pubkey);
    }

    final bool verify(T)(T pack, const Signature signature, const Pubkey pubkey) const
    if (isHiBONRecord!T) {
        return verify(pack.toDoc, signature, pubkey);
    }

    // The private should be added implicite by the GossipNet
    // The message is a hash of the 'real' message
    Signature sign(const Fingerprint message) const;

    final Signed sign(const Document doc) const {

        

            .check(doc.keys.front[0]!is HiBONPrefix.HASH, ConsensusFailCode
            .SECURITY_MESSAGE_HASH_KEY);
        const fingerprint = calcHash(doc);
        return Signed(sign(fingerprint), fingerprint);
    }

    final Signed sign(T)(T pack) const if (isHiBONRecord!T) {
        return sign(pack.toDoc);
    }

    void createKeyPair(ref ubyte[] privkey);
    void generateKeyPair(string passphrase);
    bool secKeyVerify(scope const(ubyte[]) privkey) const;
    void eraseKey() pure nothrow;

    immutable(ubyte[]) ECDHSecret(
            scope const(ubyte[]) seckey,
    scope const(Pubkey) pubkey) const;

    immutable(ubyte[]) ECDHSecret(scope const(Pubkey) pubkey) const;

    Pubkey computePubkey(scope const(ubyte[]) seckey, immutable bool compress = true) const;

    void derive(string tweak_word, shared(SecureNet) secure_net);
    void derive(const(ubyte[]) tweak_code, shared(SecureNet) secure_net);
    void derive(string tweak_word, ref ubyte[] tweak_privkey);
    void derive(const(ubyte[]) tweak_code, ref ubyte[] tweak_privkey);
    const(SecureNet) derive(const(ubyte[]) tweak_code) const;
    Pubkey derivePubkey(const(ubyte[]) tweak_code);
    Pubkey derivePubkey(string tweak_word);

    Buffer mask(const(ubyte[]) _mask) const;

}
