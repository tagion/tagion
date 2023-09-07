module tagion.wallet.EvilWallet;
import tagion.wallet.SecureWallet;

import std.format;
import std.string : representation;
import std.algorithm : map, max, min, sum, until, each, filter, cache;
import std.range : tee;
import std.array;
import std.exception : assumeUnique;
import core.time : MonoTime;
import std.conv : to;
import std.stdio;

import std.stdio;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONRecord;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONException : HiBONRecordException;

import tagion.basic.basic : basename;
import tagion.basic.Types : Buffer;
import tagion.crypto.Types : Pubkey;
import tagion.script.prior.StandardRecords;
import tagion.crypto.SecureNet : scramble;
import tagion.crypto.SecureInterfaceNet : SecureNet;

// import tagion.gossip.GossipNet : StdSecureNet, StdHashNet, scramble;
import tagion.basic.Message;
import tagion.utils.Miscellaneous;
import tagion.Keywords;
import tagion.script.TagionCurrency;
import tagion.communication.HiRPC;
import tagion.wallet.KeyRecover;
import tagion.wallet.WalletRecords : RecoverGenerator, DevicePIN;
import tagion.wallet.SecureWallet : check;

@safe struct EvilWallet(Net) {
    static assert(is(Net : SecureNet));
    protected RecoverGenerator _wallet;
    protected DevicePIN _pin;

    AccountDetails account;
    protected SecureNet net;

    //    @disable this();

    this(DevicePIN pin, RecoverGenerator wallet = RecoverGenerator.init, AccountDetails account = AccountDetails
            .init) { //nothrow {
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

    @nogc const(RecoverGenerator) wallet() pure const nothrow {
        return _wallet;
    }

    @nogc const(DevicePIN) pin() pure const nothrow {
        return _pin;
    }

    @nogc uint confidence() pure const nothrow {
        return _wallet.confidence;
    }

    static EvilWallet createWallet(
            scope const(string[]) questions,
    scope const(char[][]) answers,
    uint confidence,
    const(char[]) pincode)
    in {
        assert(questions.length > 3, "Minimal amount of answers is 4");
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
        EvilWallet result;
        {
            auto R = new ubyte[net.hashSize];
            scope (exit) {
                scramble(R);
            }
            recover.findSecret(R, questions, answers);
            net.createKeyPair(R);
            auto wallet = RecoverGenerator(recover.toDoc);
            result = EvilWallet(DevicePIN.init, wallet);
            result.set_pincode(recover, R, pincode, net);

        }
        return result;
    }

    protected void set_pincode(
            const KeyRecover recover,
            scope const(ubyte[]) R,
    scope const(char[]) pincode,
    Net _net = null) {
        const hash_size = ((net) ? net : _net).hashSize;
        auto seed = new ubyte[hash_size];
        scramble(seed);
        _pin.U = seed.idup;
        const pinhash = recover.checkHash(pincode.representation, _pin.U);
        _pin.D = xor(R, pinhash);
        _pin.S = recover.checkHash(R);
    }

    bool correct(const(string[]) questions, const(char[][]) answers)
    in {
        assert(questions.length is answers.length, "Amount of questions should be same as answers");
    }
    do {
        net = new Net;
        auto recover = KeyRecover(net, _wallet);
        scope R = new ubyte[net.hashSize];
        return recover.findSecret(R, questions, answers);
    }

    bool recover(const(string[]) questions, const(char[][]) answers, const(char[]) pincode)
    in {
        assert(questions.length is answers.length, "Amount of questions should be same as answers");
    }
    do {
        net = new Net;
        auto recover = KeyRecover(net, _wallet);
        auto R = new ubyte[net.hashSize];
        const result = recover.findSecret(R, questions, answers);
        if (result) {
            // auto pinhash = recover.checkHash(pincode.representation, _pin.U);
            set_pincode(recover, R, pincode);
            net.createKeyPair(R);
            return true;
        }
        net = null;
        return false;
    }

    @nogc bool isLoggedin() pure const nothrow {
        pragma(msg, "fixme(cbr): Jam the net");
        return net !is null;
    }

    protected void checkLogin() pure const {
        check(isLoggedin(), "Need login first");
    }

    bool login(const(char[]) pincode) {
        if (_pin.D) {
            logout;
            auto hashnet = new Net;
            auto recover = KeyRecover(hashnet);
            auto pinhash = recover.checkHash(pincode.representation, _pin.U);
            auto R = new ubyte[hashnet.hashSize];
            _pin.recover(R, pinhash);
            if (_pin.S == recover.checkHash(R)) {
                net = new Net;
                net.createKeyPair(R);
                return true;
            }
        }
        return false;
    }

    void logout() pure nothrow {
        net = null;
    }

    bool check_pincode(const(char[]) pincode) {
        const hashnet = new Net;
        auto recover = KeyRecover(hashnet);
        const pinhash = recover.checkHash(pincode.representation, _pin.U);
        scope R = new ubyte[hashnet.hashSize];
        _pin.recover(R, pinhash);
        return _pin.S == recover.checkHash(R);
    }

    bool change_pincode(const(char[]) pincode, const(char[]) new_pincode) {
        const hashnet = new Net;
        auto recover = KeyRecover(hashnet);
        const pinhash = recover.checkHash(pincode.representation, _pin.U);
        auto R = new ubyte[hashnet.hashSize];
        // xor(R, _pin.D, pinhash);
        _pin.recover(R, pinhash);
        if (_pin.S == recover.checkHash(R)) {
            // const new_pinhash = recover.checkHash(new_pincode.representation, _pin.U);
            set_pincode(recover, R, new_pincode);
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
        account.derive_state = net.rawCalcHash(
                seed ~ account.derive_state ~ current_time.representation);
        scramble(seed);
        auto pkey = net.derivePubkey(account.derive_state);
        invoice.pkey = pkey;
        account.derives[pkey] = account.derive_state;
    }

    // void registerInvoices(ref Invoice[] invoices) {
    //     invoices.each!((ref invoice) => registerInvoice(invoice));
    // }

    static Invoice createInvoice(string label, TagionCurrency amount, Document info = Document.init) {
        Invoice new_invoice;
        new_invoice.name = label;
        new_invoice.amount = amount;
        new_invoice.info = info;
        return new_invoice;
    }

    bool payment(const(Invoice[]) orders, ref SignedContract result, bool setfee, double fee, bool invalid_signature, bool zero_pubkey, bool invalid_data_type) {
        checkLogin;
        const topay = orders.map!(b => b.amount).sum;

        // removed topay check.
        const size_in_bytes = 500;
        TagionCurrency fees;
        if (setfee) {
            fees = fee.to!double.TGN;
        }
        else {
            fees = globals.fees();
        }

        const amount = topay + fees;
        StandardBill[] contract_bills;
        collect_bills(amount, contract_bills); // changed to always be true.

        const total = contract_bills.map!(b => b.value).sum;

        result.contract.inputs = contract_bills.map!(b => net.calcHash(b.toDoc)).array;
        const rest = total - amount;
        if (rest > 0) {
            Invoice money_back;
            money_back.amount = rest;
            registerInvoice(money_back);

            // 
            if (zero_pubkey) {
                auto zero_pkey = new HiBON();
                result.contract.output[money_back.pkey] = Document(zero_pkey.serialize);
                // result.contract.output[money_back.pkey] = Document(cast(ubyte[]) [0,0,0,0]);
            }
            else if (invalid_data_type) {
                string invalid_rest = "test";
                auto hibon_rest = new HiBON();
                hibon_rest[0] = invalid_rest;
                result.contract.output[money_back.pkey] = Document(hibon_rest);
            }
            else {
                result.contract.output[money_back.pkey] = rest.toDoc;
            }
        }

        // set the pubkey of the contracts to 0x000
        if (zero_pubkey) {
            auto zero_pkey = new HiBON();
            orders.each!((o) { result.contract.output[o.pkey] = Document(zero_pkey.serialize); });
        }
        else if (invalid_data_type) {
            string invalid_amount = "testing";
            auto hibon_output = new HiBON();
            hibon_output[0] = invalid_amount;
            orders.each!((o) { result.contract.output[o.pkey] = Document(hibon_output); });
        }
        else {
            orders.each!((o) { result.contract.output[o.pkey] = o.amount.toDoc; });
        }

        result.contract.script = Script("pay");

        immutable message = net.calcHash(result.contract.toDoc); //take the hash of the document.
        auto shared_net = (() @trusted { return cast(shared) net; })();
        auto bill_net = new Net;
        // Sign all inputs
        result.signs = contract_bills
            .filter!(b => b.owner in account.derives)
            .map!((b) {
                if (invalid_signature) {
                    immutable tweak_code = "invalid_signature_message";
                    bill_net.derive(tweak_code, shared_net);
                    return bill_net.sign(message);
                }
                immutable tweak_code = account.derives[b.owner];
                bill_net.derive(tweak_code, shared_net);
                return bill_net.sign(message);
            })
            .array;
        return true;

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

    @trusted
    void deactivate_bills() {
        account.activated.clear;
    }

    const(HiRPC.Sender) get_request_update_wallet() const {
        HiRPC hirpc;
        auto h = new HiBON;
        h = account.derives.byKey.map!(p => cast(Buffer) p);
        return hirpc.search(h);
    }

    void collect_bills(const TagionCurrency amount, out StandardBill[] active_bills) {
        import std.algorithm.sorting : isSorted, sort;
        import std.algorithm.iteration : cumulativeFold;
        import std.range : takeOne, tee;

        if (!account.bills.isSorted!"a.value > b.value") {
            account.bills.sort!"a.value > b.value";
        }

        // Select all bills not in use
        auto none_active = account.bills.filter!(b => !(b.owner in account.activated));

        // Check if we have enough money

        TagionCurrency rest = amount;
        active_bills = none_active.filter!(b => b.value <= rest)
            .until!(b => rest <= 0)
            .tee!((b) { rest -= b.value; account.activated[b.owner] = true; })
            .array;
        if (rest > 0) {
            // Take an extra larger bill if not enough
            StandardBill extra_bill;
            none_active.each!(b => extra_bill = b);
            account.activated[extra_bill.owner] = true;
            active_bills ~= extra_bill;
        }

    }

    @trusted
    bool set_response_update_wallet(const(HiRPC.Receiver) receiver) nothrow {
        if (receiver.isResponse) {
            try {
                account.bills = receiver.response.result[].map!(e => StandardBill(e.get!Document))
                    .array;
                return true;
            }
            catch (Exception e) {
                import std.stdio;
                import std.exception : assumeWontThrow;

                assumeWontThrow(() => writeln("Error on setresponse: %s", e.msg));
                // Ingore
            }
        }
        return false;
    }

    static TagionCurrency calcTotal(const(StandardBill[]) bills) pure {
        return bills.map!(b => b.value).sum;
    }
}
