/** 
* Wallet records to store the wallet information
*/
module tagion.wallet.WalletRecords;

import tagion.hibon.HiBONRecord;
import tagion.wallet.KeyRecover : KeyRecover;
import tagion.basic.Types : Buffer;
import tagion.crypto.Types : Pubkey;
import tagion.script.TagionCurrency;
import tagion.script.StandardRecords : StandardBill, OwnerKey;

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

@safe
struct AccountDetails {
    @label("$derives") Buffer[Pubkey] derives;
    @label("$bills") StandardBill[] bills;
    @label("$state") Buffer derive_state;
    @label("$locked") bool[Pubkey] activated; /// locked bills
    import std.algorithm : map, sum, filter, any, each;

    bool remove_bill(Pubkey pk) {
        import std.algorithm : remove, countUntil;

        const index = countUntil!"a.owner == b"(bills, pk);
        if (index > 0) {
            bills = bills.remove(index);
            return true;
        }
        return false;
    }

    void add_bill(StandardBill bill) {
        bills ~= bill;
    }

    /++
         Clear up the Account
         Remove used bills
         +/
    void clearup() pure {
        bills
            .filter!(b => b.owner in derives)
            .each!(b => derives.remove(b.owner));
        bills
            .filter!(b => b.owner in activated)
            .each!(b => activated.remove(b.owner));
    }

    const pure {
        /++
         Returns:
         true if the all transaction has been registered as processed
         +/
        bool processed() nothrow {
            return bills
                .any!(b => (b.owner in activated));
        }
        /++
         Returns:
         The available balance
         +/
        TagionCurrency available() {
            return bills
                .filter!(b => !(b.owner in activated))
                .map!(b => b.value)
                .sum;
        }
        /++
         Returns:
         The total locked amount
         +/
        TagionCurrency locked() {
            return bills
                .filter!(b => b.owner in activated)
                .map!(b => b.value)
                .sum;
        }
        /++
         Returns:
         The total balance including the locked bills
         +/
        TagionCurrency total() {
            return bills
                .map!(b => b.value)
                .sum;
        }
    }
    mixin HiBONRecord;
}
