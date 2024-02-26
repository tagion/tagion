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

import tagion.crypto.SecureNet;

const hash_net = new StdHashNet;

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

    void remove_bill_by_hash(const(DARTIndex) billHash) {
        import std.algorithm : remove, countUntil;

        const billsHashes = bills.map!(b => cast(Buffer) hash_net.calcHash(b.toDoc.serialize)).array;
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
    int check_contract_payment(const(DARTIndex)[] inputs, const(Document[]) outputs) const {
        import std.algorithm : countUntil;

        auto billsHashes = bills.map!(b => cast(Buffer) hash_net.calcHash(b.toDoc.serialize)).array;

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

    bool add_bill(TagionBill bill) {
        auto index = hash_net.dartIndex(bill);
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
        requested[hash_net.dartIndex(bill)] = bill;
    }

    const {
        /++
         Returns:
         The available balance
         +/
        TagionCurrency available() {
            return bills
                .filter!(b => !(hash_net.dartIndex(b) in activated))
                .map!(b => b.value)
                .sum;
        }
        /++
         Returns:
         The total locked amount
         +/
        TagionCurrency locked() {
            return bills
                .filter!(b => hash_net.dartIndex(b) in activated)
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

            const used_bills_hash = used_bills.map!(b => dartIndex(hash_net, b)).array;
            const bills_hash = bills.map!(b => dartIndex(hash_net, b)).array;

            TagionCurrency[] fees;
            ContractStatus[] statuses;

            /// FIXME: this messes up when contracts has multiple outputs excluding the ones to yourself
            foreach (contract, pay_script; zip(contracts, pay_scripts)) {
                TagionBill[] input_bills;

                ContractStatus status = ContractStatus.succeeded;
                foreach (input; contract.inputs) {
                    // If the input bill in the contract has been spent, the contract has succeeded
                    const used_index = used_bills_hash.countUntil(input);
                    if (used_index >= 0) {
                        input_bills ~= used_bills[used_index];
                        continue;
                    }
                    // Otherwise if it's still your bill then the contract is probably pending
                    // Could probably use activated here instead
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
            auto sent_hist_item = zip(sent_bills, fees, statuses)
                .map!(a => HistoryItem( /*bill*/ a[0], HistoryItemType.send, /*fee*/ a[1], /*status*/ a[2]));
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

version(unittest) {
import std.range;

HiRPC.Sender create_contract(
        TagionCurrency change,
        TagionCurrency sent,
        TagionCurrency fee,
        Pubkey sender,
        Pubkey receiver,
        out TagionBill input_bill
    ) {

    input_bill = TagionBill(change + fee + sent, sdt_t(0), sender, []);
    const change_bill = TagionBill(change, sdt_t(1), sender, []);
    const receiver_bill = TagionBill(sent, sdt_t(1), receiver, []);

    const script = PayScript([change_bill, receiver_bill]);
    const contract = Contract([hash_net.dartIndex(input_bill)], reads: null, script.toDoc);
    const s_contract = SignedContract(signs: null, contract);
    return HiRPC(null).submit(s_contract);
}

void create_payment(
        ref AccountDetails account,
        TagionCurrency change,
        TagionCurrency sent,
        TagionCurrency fee,
        Pubkey sender,
        Pubkey receiver
    ) {

    TagionBill input_bill;
    const rpc = create_contract(change, sent, fee, sender, receiver, input_bill);

    account.used_bills ~= input_bill;
    account.hirpcs ~= rpc.toDoc;
}

void create_pending_payment(
        ref AccountDetails account,
        TagionCurrency change,
        TagionCurrency sent,
        TagionCurrency fee,
        Pubkey sender,
        Pubkey receiver
    ) {

    TagionBill input_bill;
    const rpc = create_contract(change, sent, fee, sender, receiver, input_bill);

    account.bills ~= input_bill;
    account.activated[hash_net.dartIndex(input_bill)] = true;
    account.hirpcs ~= rpc.toDoc;
}

}

/// AccountHistory
unittest {
    import std.stdio;
    import tagion.hibon.HiBONJSON;

    auto my_net = new StdSecureNet;
    my_net.generateKeyPair("account_history");

    auto your_net = new StdSecureNet;
    your_net.generateKeyPair("I am someone else");

    {// Received
        AccountDetails account;
        account.derivers[my_net.pubkey] = [0];
        account.bills ~= TagionBill(997.TGN, sdt_t(0), my_net.pubkey, []);

        assert(account.history.walkLength == 1);
        const item = account.history.front;
        assert(item.bill.value == 997.TGN, format("Incorrect amount received %s", item.bill.value));
        // We don't know the fee
        assert(item.fee == 0.TGN, format("Incorrect amount fee %s", item.fee));
        assert(item.type == HistoryItemType.receive, "Should've been receive history item");
        // Balance is not calculated on non reverse_history()
    }

    {// Sent
        AccountDetails account;
        account.derivers[my_net.pubkey] = [0];
        account.create_payment(
            change: 400.TGN,
            sent: 2400.TGN,
            fee: 80.TGN,
            sender: my_net.pubkey,
            receiver: your_net.pubkey,
        );

        assert(account.history.walkLength == 2);
        auto hist = account.reverse_history;
        const item = hist.front;
        assert(item.bill.value == 2400.TGN, format("Incorrect amount sent %s", item.bill.value));
        assert(item.fee == 80.TGN, format("Incorrect amount fee %s", item.fee));
        assert(item.type == HistoryItemType.send, format("should've been sent history item: %s", item.type));
        assert(item.status == ContractStatus.succeeded, format("should've been succeeded item: %s", item.status));

        // create_payment creates the input bill and uses everything, so balance should be 0
        assert(item.balance == 0.TGN);
    }

    {// Pending
        AccountDetails account;
        account.derivers[my_net.pubkey] = [0];
        account.create_pending_payment(
            change: 400.TGN,
            sent: 2400.TGN,
            fee: 80.TGN,
            sender: my_net.pubkey,
            receiver: your_net.pubkey,
        );

        auto hist = account.reverse_history;

        assert(account.history.walkLength == 2);

        const item = hist.front;
        assert(item.bill.value == 2400.TGN, format("Incorrect amount sent %s", item.bill.value));
        assert(item.type == HistoryItemType.send, format("should've been sent history item: %s", item.type));
        assert(item.status == ContractStatus.pending, format("should've been pending item: %s", item.status));
        assert(item.fee == 80.TGN, format("Incorrect amount fee %s", item.fee));

        // This is probably not the expected behaviour
        // But for future the function which calculates the balance would have to backtrack because it doesn't know the balance of the future
        // For interleaved pending transactions, i don't know what to do with past transactions potentially completed in the future.
        assert(item.balance == account.total);
    }

    version(none) // BUG: this is not currently implemented
    {// Payment to self, should result in two history items, one for the sent bill and one for the received
        AccountDetails account;
        account.derivers[my_net.pubkey] = [0];
        account.create_payment(
            change: 400.TGN,
            sent: 2400.TGN,
            fee: 80.TGN,
            sender: my_net.pubkey,
            receiver: my_net.pubkey,
        );

        auto hist = account.history;
        hist.popFront; // Pop initial received bill
        assert(account.history.walkLength == 2);
        {//Sent
            const item = hist.front;
            assert(item.bill.value == 2400.TGN, format("Incorrect amount sent %s", item.bill.value));
            assert(item.type == HistoryItemType.send, format("should've been sent history item: %s", item.type));
            assert(item.status == ContractStatus.succeeded, format("should've been succeeded item: %s", item.status));
            assert(item.fee == 80.TGN, format("Incorrect amount fee %s", item.fee));
        }
        hist.popFront;
        {//Received
            const item = hist.front;
            assert(item.bill.value == 2400.TGN, format("Incorrect amount sent %s", item.bill.value));
            assert(item.type == HistoryItemType.receive, format("should've been receive history item: %s", item.type));
            assert(item.status == ContractStatus.succeeded, format("should've been succeeded item: %s", item.status));
            assert(item.fee == 0.TGN, format("Incorrect amount fee %s", item.fee));
        }
    }
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
    void reject_hipc(HiRPC.Sender hirpc) {
        // -= hirpcs
        // unlock bills
    }

    // Update
    void update(HiRPC.Receiver receiver) {
        // Add new bills
        // move locked bills to used bills if' its output of pending hirpc.
    }
}
