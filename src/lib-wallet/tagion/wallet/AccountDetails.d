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
        private auto history_impl() {
            import tagion.communication.HiRPC;
            import std.range;
            import tagion.dart.DARTBasic;
            import tagion.crypto.SecureNet;

            // Contract[] map
            auto contracts = hirpcs.map!(d => HiRPC.Receiver(d))
                .filter!(rpc => rpc.method.params.isRecord!SignedContract)
                .map!(rpc => SignedContract(rpc.method.params).contract);

            // PayScript[] map
            auto pay_scripts = contracts
                .map!(c => PayScript(c.script));

            const net = new StdHashNet();
            const used_bills_hash = used_bills.map!(b => dartIndex(net, b)).array;
            const bills_hash = bills.map!(b => dartIndex(net, b)).array;

            TagionCurrency[] fees;
            ContractStatus[] statuses;

            /// FIXME: this messes up when contracts has multiple outputs
            foreach (contract, pay_script; zip(contracts, pay_scripts)) {
                TagionBill[] input_bills;

                ContractStatus status = ContractStatus.succeeded;
                foreach (input; contract.inputs) {
                    const used_index = used_bills_hash.countUntil(input);
                    if (used_index >= 0) {
                        input_bills ~= used_bills[used_index];
                        continue;
                    }
                    const index = bills_hash.countUntil(input);
                    if (index >= 0) {
                        input_bills ~= bills[index];
                        status = ContractStatus.pending;
                    }
                }
                statuses ~= status;

                const in_sum = input_bills.map!(b => b.value).sum;
                const out_sum = pay_script.outputs.map!(b => b.value).sum;

                if (input_bills.length == 0 || pay_script.outputs.length == 0) {
                    fees ~= TGN(0);
                    continue;
                }
                fees ~= (in_sum - out_sum);
            }

            // Money you send to yourself, because you just can't get enough of it
            const(TagionBill)[] change = pay_scripts.map!(s => s.outputs)
                .joiner
                .filter!(b => b.owner in derivers)
                .array;

            // Filter result TagionBill[]
            auto sent_bills = pay_scripts.map!(s => s.outputs)
                .joiner
                .filter!(b => b.owner !in derivers);

            // Filter out bills you sent to yourself
            auto received_bills = chain(bills, used_bills).filter!(b => !canFind(change, b));

            // HistoryItem[] map
            auto sent_hist_item = zip(sent_bills, fees, statuses).map!(a => HistoryItem( /*bill*/ a[0], HistoryItemType
                    .send, /*fee*/ a[1], /*status*/ a[2]));
            auto received_hist_item = received_bills.map!(b => HistoryItem(b, HistoryItemType.receive));

            return chain(sent_hist_item, received_hist_item);
        }

        auto reverse_history() {
            TagionCurrency balance = total();
            HistoryItem evaluate_balance(HistoryItem item) {
                item.balance = balance;
                if (item.status is ContractStatus.pending) {
                    return item;
                }
                with (HistoryItemType) final switch (item.type) {
                case send:
                    balance += (item.bill.value + item.fee);
                    break;
                case receive:
                    balance -= (item.bill.value);
                    break;
                }
                return item;
            }

            return history_impl.array
                .sort!((a, b) => a.bill.time > b.bill.time)
                .map!(i => evaluate_balance(i));
        }

        auto history() {
            return history_impl.array.sort!((a, b) => a.bill.time < b.bill.time);
        }

    }
    mixin HiBONRecord;
}

enum HistoryItemType {
    receive = 0,
    send = 1,
}

enum ContractStatus {
    succeeded = 1,
    pending = 0,
}

struct HistoryItem {
    TagionBill bill;
    HistoryItemType type;
    TagionCurrency fee;
    TagionCurrency balance;
    ContractStatus status;
    mixin HiBONRecord!(q{
        this(const(TagionBill) bill, HistoryItemType type, TagionCurrency fee = 0, ContractStatus status = ContractStatus.succeeded) pure nothrow {
            this.type = type;
            this.bill = bill;
            this.fee = fee;
            this.status = status;
        }
    });
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

import tagion.dart.Recorder;
import tagion.communication.HiRPC;

struct AccountManager {
    private AccountDetails _details;

    const details() => _details;

    alias total = _details.total;
    alias available = _details.available;
    alias locked = _details.locked;
    alias history = _details.history;

    // Call this if you send a hirpc submit contract
    void send_hirpc(HiRPC.Sender hirpc) {
        // ~= hirpcs
        // lock bills
    }

    // Call this if your contract has been rejected
    void reject_hirpc(HiRPC.Sender hirpc) {
        // -= hirpcs
        // unlock bills
    }

    // Update
    void update(HiRPC.Receiver receiver) {
        // Add new bills
        // move locked bills to used bills if' its output of pending hirpc.
    }
}
