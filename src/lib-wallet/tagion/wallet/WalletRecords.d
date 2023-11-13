/** 
* Wallet records to store the wallet information
*/
module tagion.wallet.WalletRecords;

import tagion.basic.Types : Buffer;
import tagion.crypto.SecureInterfaceNet : HashNet;
import tagion.crypto.Types : Pubkey;
import tagion.dart.DARTBasic;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONRecord;
import tagion.wallet.Basic : saltHash;
import tagion.wallet.KeyRecover : KeyRecover;

/// Contains the quiz question
@safe
@recordType("Quiz")
struct Quiz {
    @label("$Q") string[] questions; /// List of questions
    mixin HiBONRecord;
}

/// Devices recovery for the pincode
@safe
@recordType("PIN")
struct DevicePIN {
    Buffer D; /// Device number
    Buffer U; /// Device random
    Buffer S; /// Check sum value
    bool recover(const HashNet net, ref scope ubyte[] R, scope const(ubyte[]) P) const {
        import tagion.utils.Miscellaneous : xor;

        const pinhash = net.saltHash(P, U);
        xor(R, D, pinhash);
        return S == net.saltHash(R);
    }

    void setPin(scope const HashNet net, scope const(ubyte[]) R, scope const(ubyte[]) P, Buffer salt) scope {
        import tagion.utils.Miscellaneous : xor;

        U = salt;
        const pinhash = net.saltHash(P, U);
        D = xor(R, pinhash);
        S = net.saltHash(R);

    }

    mixin HiBONRecord;
}

@safe
unittest {
    import std.array;
    import std.random;
    import std.range;
    import std.string : representation;
    import tagion.crypto.SecureNet : StdHashNet;
    import tagion.hibon.HiBONJSON;
    import tagion.utils.Miscellaneous;

    auto rnd = Random(unpredictableSeed);
    auto rnd_range = generate!(() => uniform!ubyte(rnd));
    const net = new StdHashNet;
    //auto R=new ubyte[net.hashSize];
    {
        auto salt = iota(ubyte(0), ubyte(net.hashSize & ubyte.max)).array.idup;
        const R = rnd_range.take(net.hashSize).array;
        DevicePIN pin;
        const pin_code = "1234".representation;
        pin.setPin(net, R, pin_code, salt);

        ubyte[] recovered_R = new ubyte[net.hashSize];
        { /// Recover the seed R with the correct pin-code 
            const recovered = pin.recover(net, recovered_R, pin_code);
            assert(recovered);
            assert(R == recovered_R);
        }

        { /// Try to recover the seed R with the wrong pin-code 
            const recovered = pin.recover(net, recovered_R, "wrong pin code".representation);
            assert(!recovered);
            assert(R != recovered_R);
        }

    }
}
/// Key-pair recovery generator
@safe
@recordType("Wallet")
struct RecoverGenerator {
    Buffer[] Y; /// Recorvery seed
    Buffer S; /// Check value S=H(H(R))
    @label("N") uint confidence; /// Confidence of the correct answers
    mixin HiBONRecord;
}
