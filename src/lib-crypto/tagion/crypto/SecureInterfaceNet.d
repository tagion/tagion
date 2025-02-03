/// Interfaces used for secure modules
module tagion.crypto.SecureInterfaceNet;

import std.typecons : TypedefType;
import tagion.errors.ConsensusExceptions : Check, ConsensusFailCode, SecurityConsensusException;
import tagion.basic.Types : Buffer, isBufferType;
import tagion.crypto.Types : Fingerprint, Pubkey, Signature;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONRecord : HiBONPrefix, isHiBONRecord;

alias check = Check!SecurityConsensusException;

@safe
interface HashNet {
    uint hashSize() const pure nothrow scope;

    Fingerprint calcHash(B)(scope const(B) data) const pure
    if (isBufferType!B) {
        return Fingerprint(rawCalcHash(cast(TypedefType!B) data));
    }

    immutable(Buffer) rawCalcHash(scope const(ubyte[]) data) const pure scope;
    immutable(Buffer) HMAC(scope const(ubyte[]) data) const pure;
    Fingerprint calcHash(const(Document) doc) const pure;

    Fingerprint calcHash(T)(T value) const if (isHiBONRecord!T) {
        return calcHash(value.toDoc);
    }

    string multihash() const pure nothrow;
}

@safe
interface SecureNet : HashNet {
    import std.typecons : Tuple;

    alias Signed = Tuple!(Signature, "signature", Fingerprint, "message");
    @nogc Pubkey pubkey() pure const nothrow;
    bool verify(const Fingerprint message, const Signature signature, const Pubkey pubkey) const pure;
    final bool verify(const Document doc, const Signature signature, const Pubkey pubkey) const pure {

        

            .check(doc.keys.front[0]!is HiBONPrefix.HASH, ConsensusFailCode
            .SECURITY_MESSAGE_HASH_KEY);
        immutable message = calcHash(doc);
        return verify(message, signature, pubkey);
    }

    bool verify(T)(T pack, const Signature signature, const Pubkey pubkey) const pure
    if (isHiBONRecord!T) {
        return verify(pack.toDoc, signature, pubkey);
    }

    Signature sign(const Fingerprint message) const pure;

    final Signed sign(const Document doc) const pure {
        const fingerprint = calcHash(doc);
        return Signed(sign(fingerprint), fingerprint);
    }

    Signed sign(T)(T pack) const pure if (isHiBONRecord!T) {
        return sign(pack.toDoc);
    }

    void createKeyPair(ref ubyte[] privkey) pure;
    void generateKeyPair(
            scope const(char[]) passphrase,
    scope const(char[]) salt = null,
    void delegate(scope const(ubyte[]) data) pure @safe dg = null) pure;
    void eraseKey() pure nothrow;

    immutable(ubyte[]) ECDHSecret(
            scope const(ubyte[]) seckey,
    scope const(Pubkey) pubkey) const;

    immutable(ubyte[]) ECDHSecret(scope const(Pubkey) pubkey) const;

    Pubkey getPubkey(scope const(ubyte[]) seckey) const pure;

    void derive(string tweak_word, shared(SecureNet) secure_net);
    void derive(const(ubyte[]) tweak_code, shared(SecureNet) secure_net);
    void derive(string tweak_word, ref ubyte[] tweak_privkey);
    void derive(const(ubyte[]) tweak_code, ref ubyte[] tweak_privkey);
    const(SecureNet) derive(const(ubyte[]) tweak_code) const;
    const(SecureNet) derive(B)(const B tweak_code) const if (isBufferType!B) {
        return derive(cast(const(TypedefType!B)) tweak_code);
    }

    Pubkey derivePubkey(const(ubyte[]) tweak_code);
    Pubkey derivePubkey(string tweak_word);

    SecureNet clone() const;
}
