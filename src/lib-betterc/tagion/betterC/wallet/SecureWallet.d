/// \file SecureWallet.d

module tagion.betterC.wallet.SecureWallet;

import std.string : representation;
import std.algorithm : map, max, min, sum, until, each, filter, cache;

import core.time : MonoTime;
import std.traits;

import tagion.betterC.hibon.Document : Document;
import tagion.betterC.wallet.Net;
import tagion.betterC.utils.BinBuffer;
import tagion.betterC.utils.Memory;
import tagion.betterC.utils.Miscellaneous;

import tagion.betterC.funnel.TagionCurrency;

import tagion.betterC.wallet.KeyRecover;
import tagion.betterC.wallet.WalletRecords : RecoverGenerator, DevicePIN, AccountDetails,
    Invoice, StandardBill, SignedContract;

struct SecureWallet(Net) {
    static assert(is(Net : SecureNet));
    protected RecoverGenerator _wallet;
    protected DevicePIN _pin;

    AccountDetails account;
    protected static SecureNet net;

    this(DevicePIN pin, RecoverGenerator wallet = RecoverGenerator.init, AccountDetails account = AccountDetails
            .init) {
        _wallet = wallet;
        _pin = pin;
        this.account = account;
    }

    this(const Document wallet_doc, const Document pin_doc = Document.init) {
        auto __wallet = RecoverGenerator(wallet_doc);
        DevicePIN __pin;
        if (!pin_doc.empty) {
            __pin = DevicePIN(pin_doc);
        }
        this(__pin, __wallet);
    }

    const(RecoverGenerator) wallet() const {
        return _wallet;
    }

    const(DevicePIN) pin() const {
        return _pin;
    }

    uint confidence() const {
        return _wallet.confidence;
    }

    static SecureWallet createWallet(scope const(string[]) questions,
    scope const(char[][]) answers, uint confidence, const(char[]) pincode)
    in {
        assert(questions.length > 3, "Minimal amount of answers is 3");
        assert(questions.length is answers.length, "Amount of questions should be same as answers");
    }
    do {
        KeyRecover recover;

        if (confidence == questions.length) {
            pragma(msg, "fixme(cbr): Due to some bug in KeyRecover");
            // Due to some bug in KeyRecover
            confidence--;
        }

        recover.createKey(questions, answers, confidence);
        //        StdSecureNet net;
        RecoverGenerator wallet;
        DevicePIN pin;
        {
            //         // auto R = new ubyte[net.hashSize];
            ubyte[] R;
            R.create(hashSize);

            recover.findSecret(R, questions, answers);
            auto pinhash = recover.checkHash(pincode.representation, pin.U);
            pin.D = xor(R, pinhash);
            pin.S = recover.checkHash(R);
            net.createKeyPair(R);
            wallet = RecoverGenerator(recover.toDoc);
        }
        return SecureWallet(pin, wallet);
    }

    // void load(AccountDetails account) {
    //     this.account = account;
    // }

    // protected void set_pincode(const KeyRecover recover, scope const(ubyte[]) R,
    //         const(ubyte[]) pinhash) {
    //     _pin.Y = xor(R, pinhash);
    //     _pin.check = recover.checkHash(R);
    // }

    // bool correct(const(string[]) questions, const(char[][]) answers)
    // in {
    //     assert(questions.length is answers.length, "Amount of questions should be same as answers");
    // }
    // do {
    //     // net = new Net;
    //     auto recover = KeyRecover(_wallet);
    //     ubyte[] R;
    //     R.create(hashSize);
    //     return recover.findSecret(R, questions, answers);
    // }

    // bool recover(const(string[]) questions, const(char[][]) answers, const(char[]) pincode)
    // in {
    //     assert(questions.length is answers.length, "Amount of questions should be same as answers");
    // }
    // do {
    //     // net = new Net;
    //     auto recover = KeyRecover(_wallet);
    //     // auto R = new ubyte[net.hashSize];
    //     ubyte[] R;
    //     R.create(hashSize);
    //     const result = recover.findSecret(R, questions, answers);
    //     if (result) {
    //         auto pinhash = recover.checkHash(pincode.representation);
    //         set_pincode(recover, R, pinhash);
    //         net.createKeyPair(R);
    //         return true;
    //     }
    //     // net = null;
    //     return false;
    // }

    // bool isLoggedin() const {
    //     // return net !is null;
    //     return true;
    // }

    protected void checkLogin() pure const {
    }

    bool login(const(char[]) pincode) {
        // if (_pin.Y) {
        //     logout;
        //     // auto hashnet = new Net;
        //     // auto recover = KeyRecover(hashnet);
        //     KeyRecover recover;
        //     auto pinhash = recover.checkHash(pincode.representation);
        //     // auto R = new ubyte[hashnet.hashSize];
        //     ubyte[] R;
        //     R.create(hashSize);
        //     xor(R, _pin.Y, pinhash);
        //     if (_pin.check == recover.checkHash(R)) {
        //         // net = new Net;
        //         net.createKeyPair(R);
        //         return true;
        //     }
        // }
        return false;
    }

    void logout() pure nothrow {
        // net = null;
    }

    // bool check_pincode(const(char[]) pincode) {
    //     // const hashnet = new Net;
    //     // auto recover = KeyRecover(hashnet);
    //     KeyRecover recover;
    //     const pinhash = recover.checkHash(pincode.representation);
    //     // auto R = new ubyte[hashnet.hashSize];
    //     ubyte[] R;
    //     R.create(hashSize);
    //     xor(R, _pin.Y, pinhash);
    //     return _pin.check == recover.checkHash(R);
    // }

    // bool change_pincode(const(char[]) pincode, const(char[]) new_pincode) {
    //     // const hashnet = new Net;
    //     // auto recover = KeyRecover(hashnet);
    //     KeyRecover recover;
    //     const pinhash = recover.checkHash(pincode.representation);
    //     // auto R = new ubyte[hashnet.hashSize];
    //     ubyte[] R;
    //     R.create(hashSize);
    //     xor(R, _pin.Y, pinhash);
    //     if (_pin.check == recover.checkHash(R)) {
    //         const new_pinhash = recover.checkHash(new_pincode.representation);
    //         set_pincode(recover, R, new_pinhash);
    //         logout;
    //         return true;
    //     }
    //     return false;
    // }

    void registerInvoice(ref Invoice invoice) {
        checkLogin;
        // string current_time = MonoTime.currTime.toString;
        // scope seed = new ubyte[net.hashSize];
        scope ubyte[] seed;
        seed.create(hashSize);
        scramble(seed);
        // account.derive_state = rawCalcHash(
        //         seed ~ account.derive_state ~ current_time.representation);
        // account.derive_state = rawCalcHash(seed);
        scramble(seed);
        // auto pkey = net.derivePubkey(account.derive_state);
        // invoice.pkey = pkey;
        // account.derives[pkey] = account.derive_state;
    }

    void registerInvoices(ref Invoice[] invoices) {
        invoices.each!((ref invoice) => registerInvoice(invoice));
    }

    static Invoice createInvoice(string label, TagionCurrency amount, Document info = Document.init) {
        Invoice new_invoice;
        new_invoice.name = label;
        new_invoice.amount = amount;
        new_invoice.info = info;
        return new_invoice;
    }

    bool payment(const(Invoice[]) orders, ref SignedContract result) {
        // checkLogin;
        // const topay = orders.map!(b => b.amount).sum;

        // if (topay > 0) {
        // const size_in_bytes = 500;
        // const fees = globals.fees(topay, size_in_bytes);
        //     const amount = topay + fees;
        //     StandardBill[] contract_bills;
        //     const enough = collect_bills(amount, contract_bills);
        //     if (enough) {
        //         const total = contract_bills.map!(b => b.value).sum;

        //         result.contract.input = contract_bills.map!(b => net.hashOf(b.toDoc)).array;
        //         const rest = total - amount;
        //         if (rest > 0) {
        //             Invoice money_back;
        //             money_back.amount = rest;
        //             registerInvoice(money_back);
        //             result.contract.output[money_back.pkey] = rest.toDoc;
        //         }
        //         orders.each!((o) { result.contract.output[o.pkey] = o.amount.toDoc; });
        //         result.contract.script = Script("pay");

        //         immutable message = net.hashOf(result.contract.toDoc);
        //         auto shared_net = (() @trusted { return cast(shared) net; })();
        //         SecureNet bill_net;
        //         // Sign all inputs
        //         result.signs = contract_bills.filter!(b => b.owner in account.derives)
        //             .map!((b) {
        //                 immutable tweak_code = account.derives[b.owner];
        //                 bill_net.derive(tweak_code, shared_net);
        //                 return bill_net.sign(message);
        //             }())
        //             .array;
        //         return true;
        //     }
        //     result = result.init;
        //     return false;
        // }

        return false;
    }

    TagionCurrency available_balance() const {
        return account.available;
    }

    TagionCurrency active_balance() const {
        return account.active;
    }

    // TagionCurrency total_balance() const pure {
    //     return account.total;
    // }

    // const(HiRPC.Sender) get_request_update_wallet() const {
    //     HiRPC hirpc;
    //     // auto h = new HiBON;
    //     auto h = HiBON();
    //     auto account_doc = account.derives;
    //     h = account_doc[0].get!Buffer;
    //     // h = account.derives.byKey.map!(p => cast(Buffer) p);
    //     return hirpc.search(h);
    // }

    // bool collect_bills(const TagionCurrency amount, out StandardBill[] active_bills) {
    //     import std.algorithm.sorting : isSorted, sort;
    //     import std.algorithm.iteration : cumulativeFold;
    //     import std.range : takeOne, tee;

    //     if (!account.bills.isSorted!"a.value > b.value") {
    //         account.bills.sort!"a.value > b.value";
    //     }

    //     // Select all bills not in use
    //     auto none_active = account.bills.filter!(b => !(b.owner in account.activated));

    //     // Check if we have enough money
    //     const enough = !none_active.map!(b => b.value)
    //         .cumulativeFold!((a, b) => a + b)
    //         .filter!(a => a >= amount)
    //         .takeOne
    //         .empty;
    //     if (enough) {
    //         TagionCurrency rest = amount;
    //         active_bills = none_active.filter!(b => b.value <= rest)
    //             .until!(b => rest <= 0)
    //             .tee!((b) { rest -= b.value; account.activated[b.owner] = true; })
    //             .array;
    //         if (rest > 0) {
    //             // Take an extra larger bill if not enough
    //             StandardBill extra_bill;
    //             none_active.each!(b => extra_bill = b);
    //             // .retro
    //             // .takeOne;
    //             account.activated[extra_bill.owner] = true;
    //             active_bills ~= extra_bill;
    //         }
    //         assert(rest > 0);
    //         return true;
    //     }
    //     return false;
    // }

    // bool set_response_update_wallet(const(HiRPC.Receiver) receiver) nothrow {
    //     if (receiver.isResponse) { // ???
    //             account.bills = receiver.method.params[].map!(e => StandardBill(e.get!Document))
    //                 .array;
    //             return true;
    //     }
    //     return false;
    // }

    // TagionCurrency get_balance() const pure {
    //     return calcTotal(account.bills);
    // }

    // static TagionCurrency calcTotal(const(StandardBill[]) bills) pure {
    //     return bills.map!(b => b.value).sum;
    // }

    // unittest {
    //     import std.stdio;
    //     import std.range : iota;
    //     import std.format;

    //     const pin_code = "1234";

    //     // Create a new Wallet
    //     enum {
    //         num_of_questions = 5,
    //         confidence = 3
    //     }
    //     const dummey_questions = num_of_questions.iota.map!(i => format("What %s", i)).array;
    //     const dummey_amswers = num_of_questions.iota.map!(i => format("A %s", i)).array;
    //     const wallet_doc = SecureWallet.createWallet(dummey_questions,
    //             dummey_amswers, confidence, pin_code).wallet.toDoc;

    //     const pin_doc = SecureWallet.createWallet(dummey_questions,
    //             dummey_amswers, confidence, pin_code).pin.toDoc;

    //     auto secure_wallet = SecureWallet(wallet_doc, pin_doc);
    //     const pin_code_2 = "3434";
    //     { // Login test
    //         assert(!secure_wallet.isLoggedin);
    //         secure_wallet.login(pin_code);
    //         assert(secure_wallet.check_pincode(pin_code));
    //         assert(secure_wallet.isLoggedin);
    //         secure_wallet.logout;
    //         assert(secure_wallet.check_pincode(pin_code));
    //         assert(!secure_wallet.isLoggedin);
    //         secure_wallet.login(pin_code_2);
    //         assert(secure_wallet.check_pincode(pin_code));
    //         assert(!secure_wallet.isLoggedin);
    //     }

    //     { // Key Recover faild
    //         auto test_answers = dummey_amswers.dup;
    //         test_answers[0] = "Bad answer 0";
    //         test_answers[3] = "Bad answer 1";
    //         test_answers[4] = "Bad answer 2";

    //         const result = secure_wallet.recover(dummey_questions, test_answers, pin_code_2);
    //         assert(!result);
    //         assert(!secure_wallet.isLoggedin);
    //     }

    //     { // Key Recover test
    //         auto test_answers = dummey_amswers.dup;
    //         test_answers[2] = "Bad answer 0";
    //         test_answers[4] = "Bad answer 1";

    //         const result = secure_wallet.recover(dummey_questions, test_answers, pin_code_2);
    //         assert(result);
    //         assert(secure_wallet.isLoggedin);
    //     }

    //     { // Re-login
    //         secure_wallet.logout;
    //         assert(secure_wallet.check_pincode(pin_code_2));
    //         assert(!secure_wallet.isLoggedin);
    //         secure_wallet.login(pin_code_2);
    //         assert(secure_wallet.isLoggedin);
    //     }

    //     const new_pincode = "7851";
    //     { // Fail to change pin-code
    //         const result = secure_wallet.change_pincode(new_pincode, pin_code_2);
    //         assert(!result);
    //         assert(secure_wallet.isLoggedin);
    //     }

    //     { // Change pincode
    //         const result = secure_wallet.change_pincode(pin_code_2, new_pincode);
    //         assert(result);
    //         assert(!secure_wallet.isLoggedin);
    //         secure_wallet.login(new_pincode);
    //         assert(secure_wallet.isLoggedin);
    //     }

    //     writeln("END unittest");
    // }

    // unittest { // Test for account
    //     import std.stdio;
    //     import std.range : zip;

    //     auto sender_wallet = SecureWallet(DevicePIN.init, RecoverGenerator.init);
    //     auto net = new Net;

    //     { // Add SecureNet to the wallet
    //         immutable very_securet = "Very Secret password";
    //         net.generateKeyPair(very_securet);
    //         sender_wallet.net = net;
    //     }

    //     { // Create a number of bills in the seneder_wallet
    //         auto bill_amounts = [4, 1, 100, 40, 956, 42, 354, 7, 102355].map!(a => a.TGN);
    //         auto gene = net.calcHash("gene".representation);
    //         const uint epoch = 42;

    //         const label = "some_name";
    //         auto list_of_invoices = bill_amounts.map!(a => createInvoice(label, a))
    //             .each!(invoice => sender_wallet.registerInvoice(invoice))();

    //         import tagion.utils.Miscellaneous : hex;

    //         // Add the bulls to the account with the derive keys
    //         with (sender_wallet.account) {
    //             bills = zip(bill_amounts, derives.byKey).map!(bill_derive => StandardBill(bill_derive[0],
    //                     epoch, bill_derive[1], gene)).array;
    //         }

    //         assert(sender_wallet.available_balance == bill_amounts.sum);
    //         assert(sender_wallet.total_balance == bill_amounts.sum);
    //         assert(sender_wallet.active_balance == 0.TGN);
    //     }

    //     auto receiver_wallet = SecureWallet(DevicePIN.init, RecoverGenerator.init);
    //     { // Add securety to the receiver_wallet
    //         auto receiver_net = new Net;
    //         immutable very_securet = "Very Secret password for the receriver";
    //         receiver_net.generateKeyPair(very_securet);
    //         receiver_wallet.net = receiver_net;
    //     }

    //     pragma(msg,
    //             "fixme(cbr): The following test is not finished, Need to transfer to money to receiver");
    //     SignedContract contract_1;
    //     { // The receiver_wallet creates an invoice to the sender_wallet
    //         auto invoice = SecureWallet.createInvoice("To sender 1", 13.TGN);
    //         receiver_wallet.registerInvoice(invoice);
    //         // Give the invoice to the sender_wallet and create payment
    //         sender_wallet.payment([invoice], contract_1);
    //     }

    //     SignedContract contract_2;
    //     { // The receiver_wallet creates an invoice to the sender_wallet
    //         auto invoice = SecureWallet.createInvoice("To sender 2", 53.TGN);
    //         receiver_wallet.registerInvoice(invoice);
    //         // Give the invoice to the sender_wallet and create payment
    //         sender_wallet.payment([invoice], contract_2);
    //     }
    // }
}
