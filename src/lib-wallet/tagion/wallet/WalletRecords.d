module tagion.wallet.WalletRecords;

import tagion.hibon.HiBONRecord;
import tagion.wallet.KeyRecover: KeyRecover;
import tagion.basic.Basic : Buffer, Pubkey;
import tagion.script.TagionCurrency;

@safe {
/++

+/
    @RecordType("Wallet") struct Wallet {

        KeyRecover.RecoverSeed seed;
        Pubkey pubkey;
        Buffer Y;
        Buffer check;
        mixin HiBONRecord;
    }

    @RecordType("Invoice") struct Invoice {
        string name;
        TagionCurrency amount;
        Pubkey pkey;
        mixin HiBONRecord;
    }
}
