module tagion.wallet.WalletRecords;

import tagion.hibon.HiBONRecord;
import tagion.wallet.KeyRecover: KeyRecover;
import tagion.basic.Basic : Buffer, Pubkey;
import tagion.script.TagionCurrency;
import tagion.script.StandardRecords : StandardBill;

@safe {
/++

+/
    @RecordType("Wallet") struct Wallet {
        KeyRecover.RecoverGenerator generator;
//        Pubkey pubkey; // Reduntant
        Buffer Y;
        Buffer check;
        mixin HiBONRecord;
    }


}
