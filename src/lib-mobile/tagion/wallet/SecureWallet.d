module tagion.wallet.SecureWallet;

import std.format;
import std.string: representation;
import std.algorithm: map, max, min, sum, until, each, filter, cache;
import std.range : tee;
import std.array;
import std.exception: assumeUnique;
import core.time: MonoTime;

//import std.stdio;
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
import tagion.basic.Message;
import tagion.utils.Miscellaneous;
import tagion.Keywords;
import tagion.script.TagionCurrency;
import tagion.communication.HiRPC;
import tagion.wallet.KeyRecover;
import tagion.wallet.WalletRecords : Wallet;
import tagion.wallet.WalletException : check;


//alias StdSecureWallet = SecureWallet!StdSecureNet;

@safe
struct SecureWallet(Net) {
    static assert(is(Net : SecureNet));
    protected Wallet wallet;
    AccountDetails account;
    protected SecureNet net;

//    @disable this();

    this(Wallet wallet, AccountDetails account=AccountDetails.init) { //nothrow {
        this.wallet = wallet;
        this.account = account;
    }

    this(const Document doc) {
        auto _wallet = Wallet(doc);
        this(_wallet);
    }

    final Document toDoc() const {
        return wallet.toDoc;
    }

    @nogc
    uint confidence() pure const nothrow {
        return wallet.generator.confidence;
    }

    static SecureWallet createWallet(scope const(string[]) questions, scope const(char[][]) answers, uint confidence, const(char[]) pincode)
        in {
            assert(questions.length > 3, "Minimal amount of answers is 3");
            assert(questions.length is answers.length, "Amount of questions should be same as answers");
        }
    do {
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
            auto pinhash = recover.checkHash(pincode.representation);
            wallet.Y = xor(R, pinhash);
            wallet.check = recover.checkHash(R);
            net.createKeyPair(R);
            wallet.generator = KeyRecover.RecoverGenerator(recover.toDoc);
        }
        return SecureWallet(wallet);
    }

    // void load(AccountDetails account) nothrow pure {
    //     this.account = account;
    // }

    protected void set_pincode(const KeyRecover recover, scope const(ubyte[]) R, const(ubyte[]) pinhash) {
        wallet.Y = xor(R, pinhash);
        wallet.check = recover.checkHash(R);
    }

    bool correct(const(string[]) questions, const(char[][]) answers)
        in {
        assert(questions.length is answers.length, "Amount of questions should be same as answers");
        }
    do {
        net = new Net;
        auto recover = KeyRecover(net, wallet.generator);
        scope R = new ubyte[net.hashSize];
        return recover.findSecret(R, questions, answers);
    }

    bool recover(const(string[]) questions, const(char[][]) answers, const(char[]) pincode)
        in {
        assert(questions.length is answers.length, "Amount of questions should be same as answers");
        }
    do {
        net = new Net;
        auto recover = KeyRecover(net, wallet.generator);
        auto R = new ubyte[net.hashSize];
        const result = recover.findSecret(R, questions, answers);
        if (result) {
            auto pinhash = recover.checkHash(pincode.representation);
            set_pincode(recover, R, pinhash);
            net.createKeyPair(R);
            return true;
        }
        net = null;
        return false;
    }

    @nogc
    bool isLoggedin() pure const nothrow {
        pragma(msg, "fixme(cbr): Yam the net");
        return net !is null;
    }

    protected void checkLogin() pure const {
        check(isLoggedin(), "Need login first");
    }

    bool login(const(char[]) pincode) {
        if (wallet.Y) {
        logout;
        auto hashnet = new Net;
        auto recover = KeyRecover(hashnet);
        auto pinhash = recover.checkHash(pincode.representation);
        auto R = new ubyte[hashnet.hashSize];
        xor(R, wallet.Y, pinhash);
        if (wallet.check == recover.checkHash(R)) {
            net =new Net;
            net.createKeyPair(R);
            return true;
        }
        }
        return false;
    }

    void logout() pure nothrow {
        net = null;
    }

    bool change_pincode(string pincode, string new_pincode) {
        const hashnet = new Net;
        auto recover = KeyRecover(hashnet);
        const pinhash = recover.checkHash(pincode.representation);
        auto R = new ubyte[hashnet.hashSize];
        xor(R, wallet.Y, pinhash);
        if (wallet.check == recover.checkHash(R)) {
            const new_pinhash = recover.checkHash(new_pincode.representation);
            set_pincode(recover, R, new_pinhash);
            logout;
            return true;
        }
        return false;
    }

    void registerInvoice(ref Invoice invoice) {
        checkLogin;
        string current_time = MonoTime.currTime.toString;
        scope seed = new ubyte[net.hashSize];
        scramble(seed);
        account.derive_state = net.calcHash(seed ~ account.derive_state ~ current_time.representation);
        scramble(seed);
        auto pkey = net.derivePubkey(account.derive_state);
        invoice.pkey = pkey;
        account.derives[pkey] = account.derive_state;
    }

    static Invoice createInvoice(string label, TagionCurrency amount = TagionCurrency.init, Document info = Document.init) {
        Invoice new_invoice;
        new_invoice.name = label;
        new_invoice.amount = amount;
        new_invoice.info = info;
        return new_invoice;
    }

    bool payment(const(Invoice[]) orders, ref SignedContract result) {
        checkLogin;
        const topay = orders.map!(b => b.amount).sum;

        if (topay > 0) {
            const size_in_bytes = 500;
            pragma(msg, "fixme(cbr): Storage fee needs to be estimated");
            const fees = globals.fees(topay, size_in_bytes);
            const amount = topay + fees;
            //string source;
            //uint count;
            // foreach (o; orders) {
            //     source = assumeUnique(format("%s %s", o.amount, source));
            //     //              count++;
            // }

            // Input
            // TagionCurrency amount;
            // const contract_bills = account.bills
            //     .tee!(b => amount+=b.value)
            //     .until!(b => amount >= total)
            //     .array;
            StandardBill[] contract_bills;
            const enough = collect_bills(amount, contract_bills);
            if (enough) {
                const total = contract_bills.map!(b => b.value).sum;
                // pragma(msg, "isHiBONRecord ",isHiBONRecord!(typeof(result.contract.input[0])));
                // pragma(msg, "isHiBONRecord ",typeof(contract_bills));

                result.contract.input = contract_bills.map!(b => net.hashOf(b.toDoc)).array;
                const rest = total - amount;
                if (rest > 0) {
                    Invoice money_back;
                    money_back.amount = rest;
                    registerInvoice(money_back);
                    result.contract.output[money_back.pkey] = rest.toDoc;
                }
                orders.each!((o) {result.contract.output[o.pkey] = o.amount.toDoc;});
                result.contract.script = Script("pay");

                immutable message = net.hashOf(result.contract.toDoc);
                auto shared_net = (() @trusted {return cast(shared) net;})();
                auto bill_net = new Net;
                // Sign all inputs
                result.signs = contract_bills
                    .filter!(b => b.owner in account.derives)
                    .map!(b => {
                            immutable tweak_code = account.derives[b.owner];
                            bill_net.derive(tweak_code, shared_net);
                            return bill_net.sign(message);
                        }())
                    .array;
                return true;
            }
            result = result.init;
            return false;
        }

        return false;
    }

    TagionCurrency available_balance() const pure {
        return account.available;
    }

    TagionCurrency active_balance() const pure {
        return account.active;
    }

    TagionCurrency total_balance() const pure {
        return account.total;
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
        foreach (pkey, dkey; account.account) {
            pkeys ~= cast(Buffer) pkey;
        }

        return Document(prepareSearch(pkeys));
    }

    const(HiRPC.Sender) get_request_update_wallet() const {
        HiRPC hirpc;
        auto h = new HiBON;
        h=account.derives.byKey.map!(p => cast(Buffer)p);
        return hirpc.search(h);
    }

    bool collect_bills(const TagionCurrency amount, out StandardBill[] active_bills) {
        import std.algorithm.sorting : isSorted, sort;
        import std.algorithm.iteration : cumulativeFold;
        import std.range : takeOne, tee;

        if (!account.bills.isSorted!"a.value > b.value") {
            account.bills.sort!"a.value > b.value";
        }

        // Select all bills not in use
        auto none_active = account.bills
            .filter!(b => !(b.owner in account.activated));

        // Check if we have enough money
        const enough = !none_active
            .map!(b => b.value)
            .cumulativeFold!((a, b) => a + b)
            .filter!(a => a >= amount)
            .takeOne
            .empty;
        if (enough) {
            TagionCurrency rest = amount;
            active_bills = none_active
                .filter!(b => b.value <= rest)
                .until!(b => rest <= 0)
                .tee!(b => {rest -= b.value; account.activated[b.owner] = true;})
                .array;
            if (rest > 0) {
                // Take an extra larger bill if not enough
                StandardBill extra_bill;
                none_active
                    .each!(b => extra_bill=b);
                // .retro
                // .takeOne;
                account.activated[extra_bill.owner] = true;
                active_bills ~= extra_bill;
            }
            assert(rest > 0);
            return true;
        }
        return false;
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
            account.bills = new_bills;
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
                account.bills = receiver.method.params[].map!(e => StandardBill(e.get!Document)).array;
                return true;
            }
            catch (Exception e) {
                // Ingore
            }
        }
        return false;
    }

    // TagionCurrency get_balance() const pure {
    //     return calcTotal(account.bills);
    // }

    static TagionCurrency calcTotal(const(StandardBill[]) bills) pure {
        return bills.map!(b => b.value).sum;
    }

    unittest {
        import std.stdio;
        import tagion.hibon.HiBONJSON;
        import std.range : iota;
        import std.format;
        const pin_code = "1234";

        // Create a new Wallet
        enum {
            num_of_questions = 5,
            confidence = 3
        }
        const dummey_questions = num_of_questions.iota.map!(i => format("What %s", i)).array;
        const dummey_amswers = num_of_questions.iota.map!(i => format("A %s", i)).array;
        const wallet_doc = SecureWallet.createWallet(dummey_questions, dummey_amswers, confidence, pin_code).toDoc;

        auto secure_wallet = SecureWallet(wallet_doc);
        const pin_code_2 = "3434";
        { // Login test
            assert(!secure_wallet.isLoggedin);
            secure_wallet.login(pin_code);
            assert(secure_wallet.isLoggedin);
            secure_wallet.logout;
            assert(!secure_wallet.isLoggedin);
            secure_wallet.login(pin_code_2);
            assert(!secure_wallet.isLoggedin);
        }

        { // Key Recover faild
            auto test_answers = dummey_amswers.dup;
            test_answers[0] = "Bad answer 0";
            test_answers[3] = "Bad answer 1";
            test_answers[4] = "Bad answer 2";

            const result = secure_wallet.recover(dummey_questions, test_answers, pin_code_2);
            assert(!result);
            assert(!secure_wallet.isLoggedin);
        }

        { // Key Recover test
            auto test_answers = dummey_amswers.dup;
            test_answers[2] = "Bad answer 0";
            test_answers[4] = "Bad answer 1";

            const result = secure_wallet.recover(dummey_questions, test_answers, pin_code_2);
            assert(result);
            assert(secure_wallet.isLoggedin);
        }

        { // Re-login
            secure_wallet.logout;
            assert(!secure_wallet.isLoggedin);
            secure_wallet.login(pin_code_2);
            assert(secure_wallet.isLoggedin);
        }

        const new_pincode = "7851";
        { // Fail to change pin-code
            const result=secure_wallet.change_pincode(new_pincode, pin_code_2);
            assert(!result);
            assert(secure_wallet.isLoggedin);
        }

        { // Change pincode
            const result = secure_wallet.change_pincode(pin_code_2, new_pincode);
            assert(result);
            assert(!secure_wallet.isLoggedin);
            secure_wallet.login(new_pincode);
            assert(secure_wallet.isLoggedin);
        }

        writeln("END unittest");
    }

    unittest { // Test for account
        import std.stdio;
        import std.range : zip;
        auto sender_wallet = SecureWallet(Wallet.init);
        auto net = new Net;

        { // Add SecureNet to the wallet
            immutable very_securet = "Very Secret password";
            net.generateKeyPair(very_securet);
            sender_wallet.net = net;
        }

        { // Create a number of bills in the seneder_wallet
            auto bill_amounts = [ 4, 1, 100, 40, 956, 42, 354,  7, 102355].map!(a => a.TGN);
            auto gene = net.calcHash("gene".representation);
            const uint epoch = 42;

            const label = "some_name";
            auto list_of_invoices = bill_amounts
                .map!(a => createInvoice(label, a))
                .each!(invoice => sender_wallet.registerInvoice(invoice))();

            import tagion.utils.Miscellaneous : hex;
            // Add the bulls to the account with the derive keys
            with(sender_wallet.account) {
                bills = zip(bill_amounts, derives.byKey)
                     .map!(bill_derive => StandardBill(bill_derive[0], epoch, bill_derive[1], gene))
                     .array;
            }

            assert(sender_wallet.available_balance == bill_amounts.sum);
            assert(sender_wallet.total_balance == bill_amounts.sum);
            assert(sender_wallet.active_balance == 0.TGN);
        }

        auto receiver_wallet = SecureWallet(Wallet.init);
        { // Add securety to the receiver_wallet
            auto receiver_net = new Net;
            immutable very_securet = "Very Secret password for the receriver";
            receiver_net.generateKeyPair(very_securet);
            receiver_wallet.net = receiver_net;
        }

        pragma(msg, "fixme(cbr): The following test is not finished, Need to transfer to money to receiver");
        SignedContract contract_1;
        { // The receiver_wallet creates an invoice to the sender_wallet
            auto invoice = SecureWallet.createInvoice("To sender 1", 13.TGN);
            receiver_wallet.registerInvoice(invoice);
            // Give the invoice to the sender_wallet and create payment
            sender_wallet.payment([invoice], contract_1);

            //writefln("contract_1=%s", contract_1.toPretty);
        }

        SignedContract contract_2;
        { // The receiver_wallet creates an invoice to the sender_wallet
            auto invoice = SecureWallet.createInvoice("To sender 2", 53.TGN);
            receiver_wallet.registerInvoice(invoice);
            // Give the invoice to the sender_wallet and create payment
            sender_wallet.payment([invoice], contract_2);

            //writefln("contract_2=%s", contract_2.toPretty);
        }
}
}

unittest {
    import tagion.crypto.SecureNet;
    alias StdSecureWallet = SecureWallet!StdSecureNet;

}
