module tagion.crypto.SecureInterfaceNet;

import std.typecons : TypedefType;
import tagion.basic.Types : Buffer, Pubkey, Signature, isBufferType;

import tagion.hibon.HiBONType : isHiBONType, HiBONPrefix;
import tagion.hibon.Document : Document;

import tagion.basic.ConsensusExceptions : Check, SecurityConsensusException, ConsensusFailCode;

alias check = Check!SecurityConsensusException;

@safe
interface HashNet {
    uint hashSize() const pure nothrow;

    final immutable(Buffer) calcHash(B)(scope const(B) data) const
    if (isBufferType!B) {
        return rawCalcHash(cast(TypedefType!B) data);
    }

    immutable(Buffer) rawCalcHash(scope const(ubyte[]) data) const;
    immutable(Buffer) HMAC(scope const(ubyte[]) data) const pure;
    /++
     Hash used for Merkle tree
     +/
    immutable(Buffer) calcHash(scope const(ubyte[]) h1, scope const(ubyte[]) h2) const;

immutable(Buffer) calcHash(const(Document) doc) const;

final immutable(Buffer) calcHash(T)(T value) const if (isHiBONType!T) {
    return calcHash(value.toDoc);
        }
    Buffer _hashOf(const(Document) doc) const;

    final Buffer _hashOf(T)(T value) const if (isHiBONType!T) {
        return _hashOf(value.toDoc);
    }
}

@safe
interface SecureNet : HashNet {
    import std.typecons : Tuple;

    alias Signed = Tuple!(Signature, "signature", Buffer, "message");
    @nogc Pubkey pubkey() pure const nothrow;
    bool verify(immutable(ubyte[]) message, const Signature signature, const Pubkey pubkey) const;
    final bool verify(const Document doc, const Signature signature, const Pubkey pubkey) const {

        

            .check(doc.keys.front[0]!is HiBONPrefix.HASH, ConsensusFailCode
            .SECURITY_MESSAGE_HASH_KEY);
        immutable message = rawCalcHash(doc.serialize);
        return verify(message, signature, pubkey);
    }

    final bool verify(T)(T pack, const Signature signature, const Pubkey pubkey) const
    if (isHiBONType!T) {
        return verify(pack.toDoc, signature, pubkey);
    }

    // The private should be added implicite by the GossipNet
    // The message is a hash of the 'real' message
    Signature sign(immutable(ubyte[]) message) const;

    final Signed sign(const Document doc) const {

        

            .check(doc.keys.front[0]!is HiBONPrefix.HASH, ConsensusFailCode
            .SECURITY_MESSAGE_HASH_KEY);
        immutable fingerprint = rawCalcHash(doc.serialize);
        return Signed(sign(fingerprint), fingerprint);
    }

    final Signed sign(T)(T pack) const if (isHiBONType!T) {
        return sign(pack.toDoc);
    }

    void createKeyPair(ref ubyte[] privkey);
    void generateKeyPair(string passphrase);
    bool secKeyVerify(scope const(ubyte[]) privkey) const;
    void eraseKey() pure nothrow;

    immutable(ubyte[]) ECDHSecret(
            scope const(ubyte[]) seckey, scope const(Pubkey) pubkey) const;

    immutable(ubyte[]) ECDHSecret(scope const(Pubkey) pubkey) const;

    Pubkey computePubkey(scope const(ubyte[]) seckey, immutable bool compress = true) const;

    void derive(string tweak_word, shared(SecureNet) secure_net);
    void derive(const(ubyte[]) tweak_code, shared(SecureNet) secure_net);
    void derive(string tweak_word, ref ubyte[] tweak_privkey);
    void derive(const(ubyte[]) tweak_code, ref ubyte[] tweak_privkey);
    Pubkey derivePubkey(const(ubyte[]) tweak_code);
    Pubkey derivePubkey(string tweak_word);

    Buffer mask(const(ubyte[]) _mask) const;

}
