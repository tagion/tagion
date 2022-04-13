module tagion.wallet.WalletRecords;

import tagion.hibon.HiBONRecord;
import tagion.wallet.KeyRecover : KeyRecover;
import tagion.basic.Basic : Buffer, Pubkey;
import tagion.script.TagionCurrency;
import tagion.script.StandardRecords : StandardBill;

@safe {
    @RecordType("Quiz")
    struct Quiz {
        @Label("$Q") string[] questions;
        mixin HiBONRecord;
    }

    /++

+/
    @RecordType("PIN")
    struct DevicePIN {
        Buffer D;     /// Devices Number
        Buffer S;     /// Check sum value
        void recover(ref scope ubyte[] R, scope const(ubyte[]) P) pure nothrow const {
            import tagion.utils.Miscellaneous : xor;
            xor(R, D, P);
        }
        mixin HiBONRecord;
    }

    // @RecordType("Wallet") struct Wallet {
    //     KeyRecover.RecoverGenerator generator;
    //     mixin HiBONRecord;
    // }

    @RecordType("Wallet")
    struct RecoverGenerator {
        Buffer[] Y; /// Recorvery seed
        Buffer S; /// Check value S=H(H(R))
        @Label("N") uint confidence;
        mixin HiBONRecord;
    }

}
