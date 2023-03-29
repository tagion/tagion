/// Wallet records to store the wallet information
module tagion.wallet.WalletRecords;

import tagion.hibon.HiBONRecord;
import tagion.wallet.KeyRecover : KeyRecover;
import tagion.basic.Types : Buffer;
import tagion.crypto.Types : Pubkey;
import tagion.script.TagionCurrency;
import tagion.script.StandardRecords : StandardBill;

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
    void recover(ref scope ubyte[] R, scope const(ubyte[]) P) pure nothrow const {
        import tagion.utils.Miscellaneous : xor;

        xor(R, D, P);
    }

    mixin HiBONRecord;
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
