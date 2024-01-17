module tagion.wallet.AccountDetails;
import std.format;
import std.algorithm;

import tagion.basic.Types;
import tagion.crypto.Types;

//import tagion.script.prior.StandardRecords;
import tagion.dart.DARTBasic;
import tagion.hibon.Document;
import tagion.hibon.HiBONRecord;
import tagion.utils.StdTime;
import tagion.script.TagionCurrency;
import tagion.script.common;
import tagion.script.standardnames;

@safe:

import tagion.crypto.SecureNet : StdHashNet;

const net = new StdHashNet;

@recordType("$Account")
struct AccountDetails {
    @optional string name;
    @label(StdNames.owner) @optional Pubkey owner;
    @label("$derivers") Buffer[Pubkey] derivers;
    @label("$bills") TagionBill[] bills;
    @label("$used") TagionBill[] used_bills;
    @label("$state") Buffer derive_state;
    @label("$locked") bool[DARTIndex] activated; /// locked bills
    @label("$requested") TagionBill[DARTIndex] requested; /// Requested bills
    @label("$requested_invoices") Invoice[] requested_invoices;
    @label("$hirpc") Document[] hirpcs; /// HiRPC request    

    import std.algorithm : filter;

    version (none) bool remove_bill(Pubkey pk) {
        import std.algorithm : countUntil, remove;

        const index = countUntil!"a.owner == b"(bills, pk);
        if (index > 0) {
            bills = bills.remove(index);
            return true;
        }
        return false;
    }

    void remove_bill_by_hash(const(DARTIndex) billHash) {
        import std.algorithm : remove, countUntil;

        const billsHashes = bills.map!(b => cast(Buffer) net.calcHash(b.toDoc.serialize)).array;
        const index = billsHashes.countUntil(billHash);
        if (index >= 0) {
            used_bills ~= bills[index];
            bills = bills.remove(index);
        }
    }

    void unlock_bill_by_hash(const(DARTIndex) billHash) {
        activated.remove(billHash);
    }

    pragma(msg, "I don't think this function belongs in AccountDetails");
    int check_contract_payment(const(DARTIndex)[] inputs, const(Document[]) outputs) {
        import std.algorithm : countUntil;

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
        auto index = net.dartIndex(bill);
        if (index in requested) {
            bills ~= requested[index];
            requested.remove(index);
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
        requested[net.dartIndex(bill)] = bill;
    }
    /++
         Clear up the Account
         Remove used bills
         +/
    version (none) void clearup() {
        bills
            .filter!(b => b.owner in derivers)
            .each!(b => derivers.remove(b.owner));
        bills
            .filter!(b => net.dartIndex(b) in activated)
            .each!(b => activated.remove(net.dartIndex(b)));
    }

    const {
        /++
         Returns:
         The available balance
         +/
        TagionCurrency available() {
            return bills
                .filter!(b => !(net.dartIndex(b) in activated))
                .map!(b => b.value)
                .sum;
        }
        /++
         Returns:
         The total locked amount
         +/
        TagionCurrency locked() {
            return bills
                .filter!(b => net.dartIndex(b) in activated)
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

        /// Returns an input range with history
        auto history() {
            import std.stdio;
            import tagion.communication.HiRPC;
            import tagion.utils.Term;
            import tagion.basic.Types;

            writeln("Sent");

            HistoryItemImpl[] items;

            // Money you send to yourself, because you just can't get enough of it
            const(TagionBill)[] change;

            foreach (HiRPC.Receiver rpc; hirpcs) {
                if (isRecord!SignedContract(rpc.method.params)) {
                    const s_contract = SignedContract(rpc.method.params);
                    const script = PayScript(s_contract.contract.script);
                    auto _change = script.outputs.filter!(b => b.owner in derivers);
                    HistoryItemImpl item;
                    item.type = HistoryItemType.send;
                    item.timestamp = sdt_t(script.outputs[0].time);

                    foreach (c; _change) {
                        change ~= c;
                    }

                    const sum_change = _change
                        .map!(b => b.value)
                        .sum;

                    auto receiver_bills = script.outputs.filter!(b => b.owner !in derivers);
                    const sum_receiver = receiver_bills
                        .map!(b => b.value)
                        .sum;

                    // Does not handle single transactions to multiple receivers
                    // Will look like it's only for one receiver
                    item.pubkey = Pubkey(receiver_bills.front.owner);
                    item.amount = sum_receiver;

                    items ~= item;
                    // writefln("%s%8s%s : %s%8s%s", GREEN, sum_change, RESET, RED, sum_receiver, RESET);
                }
            }

            writeln();
            writeln("Received");
            foreach (b; used_bills ~ bills) {
                if (change.canFind(b)) {
                    continue;
                }

                HistoryItemImpl item;
                with (item) {
                    type = HistoryItemType.receive;
                    pubkey = Pubkey(b.owner);
                    timestamp = sdt_t(b.time);
                    item.amount = b.value;
                }

                items ~= item;

                // writefln("%s: %s%8s%s", b.time.toText[0 .. 19], GREEN, b.value, RESET);
            }

            auto sorted_items = items.sort!((a, b) => a.timestamp < b.timestamp);

            foreach (item; sorted_items) {
                final switch (item.type) {
                case HistoryItemType.receive:
                    writefln("%s: %s%8s%s", item.timestamp.toText[0 .. 19], GREEN, item.amount, RESET);
                    break;
                case HistoryItemType.send:
                    writefln("%s: %s%8s%s to %s", item.timestamp.toText[0 .. 19], RED, item.amount, RESET, item.pubkey
                            .encodeBase64);
                    break;
                }
            }

            return 0;
        }

    }
    mixin HiBONRecord;
}

enum HistoryItemType {
    receive = 0,
    send = 1,
}

struct HistoryItemImpl {
    HistoryItemType type;
    @label(StdNames.value) TagionCurrency amount;
    @label(StdNames.time) sdt_t timestamp;
    @label(StdNames.owner) Pubkey pubkey;
    mixin HiBONRecord;
}

struct HistoryItem {
    double amount;
    double balance;
    double fee;
    int status;
    int type;
    @label(StdNames.time) sdt_t timestamp;
    Pubkey pubkey;
    mixin HiBONRecord;
}

struct History {
    HistoryItem[] items;
    mixin HiBONRecord;
}

@safe
@recordType("Invoice")
struct Invoice {
    string name; /// Name of the invoice
    TagionCurrency amount; /// Amount to be payed
    @label(StdNames.owner) Pubkey pkey; /// Key to the payee
    @optional Document info; /// Information about the invoice
    mixin HiBONRecord;
}

@safe
struct Invoices {
    Invoice[] list; /// List of invoice (store in the wallet)
    mixin HiBONRecord;
}
