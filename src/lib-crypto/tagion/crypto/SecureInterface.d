module tagion.crypto.SecureInterface;

import tagion.basic.Basic : Buffer, Pubkey, Signature;
import tagion.hibon.HiBONRecord : isHiBONRecord;
import tagion.hibon.Document : Document;

@safe
interface HashNet {
    uint hashSize() const pure nothrow;
    immutable(Buffer) calcHash(scope const(ubyte[]) data) const;
    immutable(Buffer) HMAC(scope const(ubyte[]) data) const;
    /++
     Hash used for Merkle tree
     +/
    immutable(Buffer) calcHash(scope const(ubyte[]) h1, scope const(ubyte[]) h2) const;

    immutable(Buffer) hashOf(const(Document) doc) const;

    final immutable(Buffer) hashOf(T)(T value) const if(isHiBONRecord!T) {
        return hashOf(value.toDoc);
    }
}


@safe
interface SecureNet : HashNet {
    Pubkey pubkey() pure const nothrow;
    bool verify(immutable(ubyte[]) message, const Signature signature, const Pubkey pubkey) const;
    final bool verify(const Document doc, const Signature signature, const Pubkey pubkey) const {
        immutable message=hashOf(doc);
        return verify(message, signature, pubkey);
    }
    final bool verify(T)(T pack, const Signature signature, const Pubkey pubkey) const if(isHiBONRecord!T) {
        return verify(pack.toDoc, signature, pubkey);
    }

    // The private should be added implicite by the GossipNet
    // The message is a hash of the 'real' message
    Signature sign(immutable(ubyte[]) message) const;
    final Signature sign(const Document doc) const {
        return sign(doc.serialize);
    }

    final Signature sign(T)(T pack) const if(isHiBONRecord!T) {
        return sign(pack.toDoc);
    }

    void createKeyPair(ref ubyte[] privkey);
    void generateKeyPair(string passphrase);
    void derive(string tweak_word, shared(SecureNet) secure_net);
    void derive(const(ubyte[]) tweak_code, shared(SecureNet) secure_net);
    void derive(string tweak_word, ref ubyte[] tweak_privkey);
    void derive(const(ubyte[]) tweak_code, ref ubyte[] tweak_privkey);
    Pubkey derivePubkey(const(ubyte[]) tweak_code);
    Pubkey derivePubkey(string tweak_word);

    Buffer mask(const(ubyte[]) _mask) const;

}
