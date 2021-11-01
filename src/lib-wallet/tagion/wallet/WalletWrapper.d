module tagion.wallet.WalletWrapper;

import std.format;
import std.string: representation;
import std.algorithm: map, max, min, sum, until, each, filter, cache;
import std.range : tee;
import std.array;
import std.exception: assumeUnique;
import core.time: MonoTime;

import tagion.hibon.HiBON: HiBON;
import tagion.hibon.Document: Document;
import tagion.hibon.HiBONRecord;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONException : HiBONRecordException;

import tagion.basic.Basic: basename, Buffer, Pubkey;
import tagion.script.StandardRecords;
import tagion.crypto.SecureNet: scramble;
import tagion.crypto.SecureInterfaceNet: SecureNet;

// import tagion.gossip.GossipNet : StdSecureNet, StdHashNet, scramble;
import tagion.wallet.KeyRecover;
import tagion.wallet.WalletRecords : Wallet;
import tagion.basic.Message;
import tagion.utils.Miscellaneous;
import tagion.Keywords;
import tagion.script.TagionCurrency;
import tagion.communication.HiRPC;


//alias StdSecureWallet = SecureWallet!StdSecureNet;

@safe
struct SecureWallet(Net) {
    static assert(is(Net : SecureNet));
    protected Wallet wallet;
    protected AccountDetails details;
    protected SecureNet net;

    @disable this();

    this(Wallet wallet, AccountDetails details=AccountDetails.init) nothrow {
        this.wallet = wallet;
        this.details = details;
//        net = new Net;
    }

//     this(WalletDetails details) nothrow {
//         this.details = details;
// //        net = new Net;
//     }

    this(const Document doc) {
        auto wallet = Wallet(doc);
        this(wallet);
    }

    // invariant {
    //     assert(net !is null);
    // }

    final Document toDoc() const {
        return wallet.toDoc;
    }

    static SecureWallet createWallet(const(string[]) questions, const(string[]) answers, uint confidence, string pincode)
    in {
        assert(questions.length > 3, "Minimal amount of answers is 3");
        assert(questions.length is answers.length, "Amount of questions should be same as answers");
    }
    do {
        import std.string : representation;
        auto net = new Net;
//        auto hashnet = new StdHashNet;
        auto recover = KeyRecover(net);

        if (confidence == questions.length) {
            pragma(msg, "fixme(cbr): Due to some bug in KeyRecover");
            // Due to some bug in KeyRecover
            confidence--;
        }

        recover.createKey(questions, answers, confidence);
//        StdSecureNet net;
        Wallet wallet;
        {
            auto R = new ubyte[net.hashSize];

            recover.findSecret(R, questions, answers);
            //writefln("R=0x%s", R.idup.hex);
            // import std.string : representation;
            auto pinhash = recover.checkHash(pincode.representation);
            //writefln("R.length=%d pinhash.length=%d", R.length, pinhash.length);
            wallet.Y = xor(R, pinhash);
            wallet.check = recover.checkHash(R);
            net.createKeyPair(R);
            pragma(msg, "fixme(cbr): wallet.pubkey is redundant");
            wallet.pubkey = net.pubkey;

            const seed_data = recover.toHiBON.serialize;
            const seed_doc = Document(seed_data);
            wallet.generator = KeyRecover.RecoverGenerator(seed_doc);
        }
        return SecureWallet(wallet);
    }

    bool isLogedin() {
        return net !is null;
    }

    void checkLogin() {
        assert(isLogedin(), "Need login first");
    }

    bool login(string pincode) {
//        auto hashnet = new StdHashNet;
        auto recover = KeyRecover(net);
        auto pinhash = recover.checkHash(pincode.representation);
        auto R = new ubyte[net.hashSize];
        xor(R, wallet.Y, pinhash);
        net =new Net;
        if (wallet.check == recover.checkHash(R)) {
//            net.eraseKey;
            //net = new StdSecureNet;
            net.createKeyPair(R);
            return true;
        }
        return false;
    }

    TagionCurrency total() const pure  {
        return SecureWallet.calcTotal(details.bills);
    }

    void registerInvoice(ref Invoice invoice)
    in {
        checkLogin;
    }
    do {
        string current_time = MonoTime.currTime.toString;
        scope seed = new ubyte[net.hashSize];
        scramble(seed);
        details.drive_state = net.calcHash(seed ~ details.drive_state ~ current_time.representation);
        scramble(seed);
        const pkey = net.derivePubkey(details.drive_state);
        invoice.pkey = cast(Buffer) pkey;
        details.account[pkey] = details.drive_state;
    }

    static Invoice createInvoice(string label, TagionCurrency amount = TagionCurrency.init) {
        Invoice new_invoice;
        new_invoice.name = label;
        new_invoice.amount = amount;
        return new_invoice;
    }

    bool payment(const(Invoice[]) orders, ref SignedContract result)
    in {
        checkLogin;
    }
    do {
        const topay = orders.map!(b => b.amount).sum;

        if (topay > 0) {
            const size_in_bytes = 500;
            pragma(msg, "fixme(cbr): Storage fee needs to be estimated");
            const fees = globals.fees(topay, size_in_bytes);
            const total = topay + fees;
            string source;
            //uint count;
            foreach (o; orders) {
                source = assumeUnique(format("%s %s", o.amount, source));
                //              count++;
            }

            // Input
            TagionCurrency amount;
            const contract_bills = details.bills
                .tee!(b => amount+=b.value)
                .until!(b => amount >= total)
                .array;
            if (amount >= total) {
                pragma(msg, "isHiBONRecord ",isHiBONRecord!(typeof(result.contract.input[0])));
                pragma(msg, "isHiBONRecord ",typeof(contract_bills));
                result.contract.input = contract_bills.map!(b => net.hashOf(b.toDoc)).array;
                const rest = amount - total;
                Invoice money_back;
                money_back.amount = rest;
                registerInvoice(money_back);
                result.contract.output[money_back.pkey] = rest.toDoc;
                pragma(msg, "orders[] ", typeof(orders[0].amount.toDoc), " ", typeof(orders[0].pkey) );
                orders.each!(o => {result.contract.output[o.pkey] = o.amount.toDoc;});
                result.contract.script = Script("pay");
            }
            else {
                return false;
            }


            // foreach (b; details.bills) {
            //     amount -= min(amount, b.value);
            //     contract_bills ~= b;
            //     if (amount == 0) {
            //         break;
            //     }
            // }
            // if (amount != 0) {
            //     return false;
            // }
            //        result.input=contract_bills; // Input _bills
            //        Buffer[] inputs;

            /*
            foreach (b; contract_bills) {
                result.contract.input ~= net.hashOf(b.toDoc);
            }
            const _total_input = WalletWrapper.calcTotal(contract_bills);
            if (_total_input >= topay) {
                const _rest = _total_input - topay;
//                count++;
                pragma(msg, "fixme(cbr): Should be change to wasm-binary");
                result.contract.script = Script.init; //cast(Buffer)assumeUnique(format("%s %s %d pay", source, _rest, count));

//                                result.contract.script = cast(Buffer)assumeUnique(format("%s %s %d pay", source, _rest, count));
// output
                Invoice money_back;
                money_back.amount = _rest;
                registerInvoice(money_back);
                result.contract.output ~= money_back.pkey;
                foreach (o; orders) {
                    result.contract.output ~= o.pkey;
                }
            }
            else {
                return false;
            }
            */
            immutable message = net.hashOf(result.contract.toDoc);
            auto shared_net = (() @trusted {return cast(shared) net;})();
            auto bill_net = new Net;
            pragma(msg, "contract_bills " , typeof(contract_bills
                    .filter!(b => b.owner in details.account)
                    .map!(b => {
                            immutable tweak_code = details.account[b.owner];
                            bill_net.derive(tweak_code, shared_net);
                            return bill_net.sign(message);
                        }())
                    .array));
            result.signs = contract_bills
                .filter!(b => b.owner in details.account)
                .map!(b => {
                        immutable tweak_code = details.account[b.owner];
                        bill_net.derive(tweak_code, shared_net);
                        return bill_net.sign(message);
                    }())
                .array;
            return true;

        }

        // Sign all inputs
        // foreach (i, b; contract_bills) {
        //     Pubkey pkey = b.owner;
        //     if (pkey in details.account) {
        //         immutable tweak_code = details.account[pkey];
        //         auto bill_net = new StdSecureNet;
        //         bill_net.derive(tweak_code, shared_net);
        //         immutable signature = bill_net.sign(message);
        //         result.signs ~= signature;
        //     }
        // }

        return false;
    }

    version(none)
    Document get_request_update_wallet() {
        HiRPC hirpc;
        Buffer prepareSearch(Buffer[] owners) {
            HiBON params = new HiBON;
            foreach (i, owner; owners) {
                params[i] = owner;
            }
            const sender = hirpc.action("search", params);
            immutable data = sender.toDoc.serialize;
            return data;
        }

        Buffer[] pkeys;
        foreach (pkey, dkey; details.account) {
            pkeys ~= cast(Buffer) pkey;
        }

        return Document(prepareSearch(pkeys));
    }

    const(HiRPC.Sender) get_request_update_wallet() const {
        HiRPC hirpc;
        auto h = new HiBON;
        h=details.account.byKey.map!(p => cast(Buffer)p);
        return hirpc.search(h);
        // return hirpc.opDispatch!"search"(h);
//        return hirpc.search(details.account.byKey.map!(p => cast(Buffer)p).array);
    }

    version(none)
    bool set_response_update_wallet(Document response_doc) {
        HiRPC hirpc;
        StandardBill[] new_bills;
        auto received = hirpc.receive(response_doc);
        if (HiRPC.getType(received) == HiRPC.Type.result) {
            foreach (bill; received.response.result[]) {
                auto std_bill = StandardBill(bill.get!Document);
                new_bills ~= std_bill;
            }
            details.bills = new_bills;
            // writeln("Wallet updated");
            return true;
        }
        else {
            // writeln("Wallet update failed");
            return false;
        }
    }

    bool set_response_update_wallet(const(HiRPC.Receiver) receiver) nothrow {
        if (receiver.isResponse) {
            try {
                details.bills = receiver.method.params[].map!(e => StandardBill(e.get!Document)).array;
                return true;
            }
            catch (Exception e) {
                // Ingore
            }
        }
        return false;
    }

    TagionCurrency get_balance() const pure {
        return calcTotal(details.bills);
    }

    static TagionCurrency calcTotal(const(StandardBill[]) bills) pure {
        return bills.map!(b => b.value).sum;
    }
}

unittest {
    import tagion.crypto.SecureNet;
    import std.range : iota;
    import std.format;
    alias StdSecureWallet = SecureWallet!StdSecureNet;
    // Create recovery
    const hashnet = new StdHashNet;
//    auto recover = KeyRecovery(hashnet);
    enum {
        num_of_questions = 5,
        confidence = 3
    }
    const dummey_question = num_of_questions.iota.map!(i => format("What %s", i)).array;
    const dummey_amswers = num_of_questions.iota.map!(i => format("A %s", i)).array;
    const pin_code = "1234";
    auto secure_wallet = StdSecureWallet.createWallet(dummey_question, dummey_amswers, confidence, pin_code);

//    recover.createKey(dummey_question, dummey_amswers, confidence);

}
