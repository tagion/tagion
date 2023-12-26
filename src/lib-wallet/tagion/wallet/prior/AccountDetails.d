module tagion.wallet.prior.AccountDetails;
import std.format;
import tagion.basic.Types;
import tagion.crypto.Types;

//import tagion.script.prior.StandardRecords;
import tagion.dart.DARTBasic;
import tagion.hibon.Document;
import tagion.hibon.HiBONRecord;
import tagion.script.TagionCurrency;
import tagion.script.common;
import tagion.script.standardnames;
import tagion.wallet.AccountDetails : Invoice;

@safe
struct AccountDetails {
    @optional string name;
    @label(StdNames.owner) @optional Pubkey owner;
    @label("$derivers") Buffer[Pubkey] derivers;
    @label("$bills") TagionBill[] bills;
    @label("$used") TagionBill[] used_bills;
    @label("$state") Buffer derive_state;
    @label("$locked") bool[Pubkey] activated; /// locked bills
    @label("$requested") TagionBill[Pubkey] requested; /// Requested bills
    @label("$requested_invoices") Invoice[] requested_invoices;
    @label("$hirpc") Document[] hirpcs; /// HiRPC request    
    import std.algorithm : any, each, filter, map, sum;

    bool remove_bill(Pubkey pk) {
        import std.algorithm : countUntil, remove;

        const index = countUntil!"a.owner == b"(bills, pk);
        if (index > 0) {
            bills = bills.remove(index);
            return true;
        }
        return false;
    }

    void remove_bill_by_hash(const(DARTIndex) billHash) {
        import std.algorithm : countUntil, remove;
        import tagion.crypto.SecureNet : StdHashNet;

        const net = new StdHashNet;

        auto billsHashes = bills.map!(b => cast(Buffer) net.calcHash(b.toDoc.serialize)).array;
        const index = billsHashes.countUntil(billHash);
        bills = bills.remove(index);
    }

    void unlock_bill_by_hash(const(DARTIndex) billHash) {
        import std.algorithm : countUntil, remove;
        import tagion.crypto.SecureNet : StdHashNet;

        const net = new StdHashNet;

        auto billsHashes = bills.map!(b => cast(Buffer) net.calcHash(b.toDoc.serialize)).array;
        const index = billsHashes.countUntil(billHash);

        activated.remove(bills[index].owner);
    }

    pragma(msg, "I don't think this function belongs in AccountDetails");
    int check_contract_payment(const(DARTIndex)[] inputs, const(Document[]) outputs) {
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
        foreach (outputPubkey; outputs.map!(output => output[StdNames.owner].get!Pubkey)) {
            const index = countUntil!"a.owner == b"(bills, outputPubkey);
            if (index >= 0) {
                return 1;
            }
        }

        if (bills.length == 0) {
            return 1;
        }

        return 2;
    }

    bool check_invoice_payment(Pubkey invoicePubkey, ref TagionCurrency amount) {
        import std.algorithm : countUntil;

        const index = countUntil!"a.owner == b"(bills, invoicePubkey);
        if (index >= 0) {
            amount = bills[index].value;
            return true;
        }
        return false;
    }

    bool add_bill(TagionBill bill) {
        if (bill.owner in requested) {
            bills ~= requested[bill.owner];
            requested.remove(bill.owner);
            return true;
        }
        return false;
    }

    TagionBill add_bill(const Document doc) {
        auto bill = TagionBill(doc);
        const added = add_bill(bill);
        if (added) {
            return bill;
        }
        return TagionBill.init;
    }

    void requestBill(TagionBill bill, Buffer derive) {
        check((bill.owner in derivers) is null, format("Bill %(%x%) already exists", bill.owner));
        derivers[bill.owner] = derive;
        requested[bill.owner] = bill;
    }
    /++
         Clear up the Account
         Remove used bills
         +/
    void clearup() pure {
        bills
            .filter!(b => b.owner in derivers)
            .each!(b => derivers.remove(b.owner));
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
