module tagion.wallet.WalletRecords;

import tagion.hibon.HiBONRecord;
import tagion.wallet.KeyRecover : KeyRecover;
import tagion.basic.Types : Buffer;
import tagion.crypto.Types :  Pubkey;
import tagion.script.TagionCurrency;
import tagion.script.StandardRecords : StandardBill;

@safe {
    @recordType("Quiz")
    struct Quiz {
        @label("$Q") string[] questions;
        mixin HiBONType;
    }

    /++

+/
    @recordType("PIN")
    struct DevicePIN {
        Buffer D; /// Device number
        Buffer U; /// Device random
        Buffer S; /// Check sum value
        void recover(ref scope ubyte[] R, scope const(ubyte[]) P) pure nothrow const {
            import tagion.utils.Miscellaneous : xor;

            xor(R, D, P);
        }

        mixin HiBONType;
    }

    // @recordType("Wallet") struct Wallet {
    //     KeyRecover.RecoverGenerator generator;
    //     mixin HiBONType;
    // }

    @recordType("Wallet")
    struct RecoverGenerator {
        Buffer[] Y; /// Recorvery seed
        Buffer S; /// Check value S=H(H(R))
        @label("N") uint confidence;
        mixin HiBONType;
    }

}
