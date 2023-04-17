module tagion.wallet.BIP39;

@trusted
ubyte[] bip39(const(ushort[]) mnemonic) pure nothrow
{
    pragma(msg, "fixme(cbr): Fake BIP39 must be fixed later");
    import std.digest.sha : SHA256;
    import std.digest;
    return digest!SHA256(cast(ubyte[]) mnemonic).dup;
}
