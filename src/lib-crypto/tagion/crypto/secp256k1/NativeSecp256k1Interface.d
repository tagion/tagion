module tagion.crypto.secp256k1.NativeSecp256k1Interface;

interface NativeSecp256k1 {
    bool verify(const(ubyte[]) msg, const(ubyte[]) signature, const(ubyte[]) pub) const;
    immutable(ubyte[]) sign(const(ubyte[]) msg, const(ubyte[]) seckey) const;
    immutable(ubyte[]) getPubkey(scope const(ubyte[]) seckey) const;
    void privTweak(
            const(ubyte[]) privkey,
    const(ubyte[]) tweak,
    ref ubyte[] tweak_privkey) const;
    immutable(ubyte[]) pubTweak(scope const(ubyte[]) pubkey, scope const(ubyte[]) tweak) const;

    immutable(ubyte[]) createECDHSecret(
            scope const(ubyte[]) seckey,
    const(ubyte[]) pubkey) const;

}
