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
import tagion.hibon.Document : Document;

import tagion.dart.DARTBasic;
import std.stdio;

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
    bool recover(const KeyRecover recover, ref scope ubyte[] R, scope const(ubyte[]) P) const {
        import tagion.utils.Miscellaneous : xor;

        const pinhash = recover.checkHash(P, U);
        xor(R, D, pinhash);
        return S == recover.checkHash(R);
    }

    void setPin(const KeyRecover recover, scope const(ubyte[]) R, scope const(ubyte[]) P, Buffer salt) {
        import tagion.utils.Miscellaneous : xor;

        U = salt;
        const pinhash = recover.checkHash(P, U);
        D = xor(R, pinhash);
        S = recover.checkHash(R);

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

    void remove_bill_by_hash(const(DARTIndex) billHash) {
        import std.algorithm : remove, countUntil;
        import tagion.crypto.SecureNet : StdHashNet;

        const net = new StdHashNet;

        auto billsHashes = bills.map!(b => cast(Buffer) net.calcHash(b.toDoc.serialize)).array;
        const index = billsHashes.countUntil(billHash);
        bills = bills.remove(index);
    }

    void unlock_bill_by_hash(const(DARTIndex) billHash) {
        import std.algorithm : remove, countUntil;
        import tagion.crypto.SecureNet : StdHashNet;

        const net = new StdHashNet;

        auto billsHashes = bills.map!(b => cast(Buffer) net.calcHash(b.toDoc.serialize)).array;
        const index = billsHashes.countUntil(billHash);

        activated.remove(bills[index].owner);
    }

    int check_contract_payment(const(DARTIndex)[] inputs, Document[Pubkey] outputs) {
        import std.algorithm : countUntil;
        import tagion.crypto.SecureNet : StdHashNet;

        const net = new StdHashNet;

        auto billsHashes = bills.map!(b => cast(Buffer) net.calcHash(b.toDoc.serialize)).array;

        // Look for input matches. Return 0 from func if found.
        foreach (inputHash; inputs) {
            const index = countUntil!"a == b"(billsHashes, inputHash);
            if (index >= 0) {
                return 0;
            }
        }
        // Proceed if inputs are not matched.
        // Look for outputs matches. Return 1 from func if found or 2 if not.
        foreach (outputPubkey; outputs.keys) {
            const index = countUntil!"a.owner == b"(bills, outputPubkey);
            if (index >= 0) {
                return 1;
            }
        }
        return 2;
    }

    TagionCurrency check_invoice_payment(Pubkey invoicePubkey) {
        import std.algorithm : countUntil;

        const index = countUntil!"a.owner == b"(bills, invoicePubkey);
        if (index >= 0) {
            return bills[index].value;
        }
        return TagionCurrency(0);
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

@safe
@recordType("Invoice")
struct Invoice {
    string name; /// Name of the invoice
    TagionCurrency amount; /// Amount to be payed
    @label(OwnerKey) Pubkey pkey; /// Key to the payee
    @label("*", true) Document info; /// Information about the invoice
    mixin HiBONRecord!();
}

@safe
struct Invoices {
    Invoice[] list; /// List of invoice (store in the wallet)
    mixin HiBONRecord;
}
