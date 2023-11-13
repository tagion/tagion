module tagion.crypto.secp256k1.NativeSecp256k1Interface;
private import tagion.crypto.secp256k1.c.secp256k1;

enum SECP256K1 : uint {
    FLAGS_TYPE_MASK = SECP256K1_FLAGS_TYPE_MASK,
    FLAGS_TYPE_CONTEXT = SECP256K1_FLAGS_TYPE_CONTEXT,
    FLAGS_TYPE_COMPRESSION = SECP256K1_FLAGS_TYPE_COMPRESSION,
    /** The higher bits contain the actual data. Do not use directly. */
    FLAGS_BIT_CONTEXT_VERIFY = SECP256K1_FLAGS_BIT_CONTEXT_VERIFY,
    FLAGS_BIT_CONTEXT_SIGN = SECP256K1_FLAGS_BIT_CONTEXT_SIGN,
    FLAGS_BIT_COMPRESSION = FLAGS_BIT_CONTEXT_SIGN,

    /** Flags to pass to secp256k1_context_create. */
    CONTEXT_VERIFY = SECP256K1_CONTEXT_VERIFY,
    CONTEXT_SIGN = SECP256K1_CONTEXT_SIGN,
    CONTEXT_NONE = SECP256K1_CONTEXT_NONE,

    /** Flag to pass to secp256k1_ec_pubkey_serialize and secp256k1_ec_privkey_export. */
    EC_COMPRESSED = SECP256K1_EC_COMPRESSED,
    EC_UNCOMPRESSED = SECP256K1_EC_UNCOMPRESSED,

    /** Prefix byte used to tag various encoded curvepoints for specific purposes */
    TAG_PUBKEY_EVEN = SECP256K1_TAG_PUBKEY_EVEN,
    TAG_PUBKEY_ODD = SECP256K1_TAG_PUBKEY_ODD,
    TAG_PUBKEY_UNCOMPRESSED = SECP256K1_TAG_PUBKEY_UNCOMPRESSED,
    TAG_PUBKEY_HYBRID_EVEN = SECP256K1_TAG_PUBKEY_HYBRID_EVEN,
    TAG_PUBKEY_HYBRID_ODD = SECP256K1_TAG_PUBKEY_HYBRID_ODD
}

interface NativeSecp256k1Interface {
    enum TWEAK_SIZE = 32;
    enum SIGNATURE_SIZE = 64;
    enum SECKEY_SIZE = 32;
    enum XONLY_PUBKEY_SIZE = 32;
    enum PUBKEY_SIZE = 33;
    enum MESSAGE_SIZE = 32;
    //   enum KEYPAIR_SIZE = secp256k1_keypair.data.length;

    bool verify(const(ubyte[]) msg, const(ubyte[]) signature, const(ubyte[]) pub) const;
    immutable(ubyte[]) sign(const(ubyte[]) msg, scope const(ubyte[]) seckey) const;
    immutable(ubyte[]) getPubkey(scope const(ubyte[]) seckey) const;
    void privTweak(
            scope const(ubyte[]) privkey,
    scope const(ubyte[]) tweak,
    out ubyte[] tweak_privkey) const;
    immutable(ubyte[]) pubTweak(scope const(ubyte[]) pubkey, scope const(ubyte[]) tweak) const;

    immutable(ubyte[]) createECDHSecret(
            scope const(ubyte[]) seckey,
    const(ubyte[]) pubkey) const;

}
