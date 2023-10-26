module tagion.crypto.secp256k1.NativeMusig;
@safe:
import std.string : representation;
import tagion.crypto.secp256k1.NativeSecp256k1;
import tagion.crypto.secp256k1.c.secp256k1_musig;
import tagion.crypto.secp256k1.c.secp256k1;

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
    @trusted
    bool tweak() {
        secp256k1_pubkey output_pk;
        {
            const ret = secp256k1_musig_pubkey_ec_tweak_add(crypt._ctx, null, &cache, &plain_tweak[0]);
        }
        {
            const ret = secp256k1_musig_pubkey_xonly_tweak_add(crypt._ctx, &output_pk, &cache, &xonly_tweak[0]);
        }
        return false;
    }
}

unittest {

}
