/**
* Handles management of key-pair, account-details device-pin
*/
module tagion.wallet.SecureWallet;

import std.format;
import std.string : representation;
import std.algorithm : map, max, min, sum, until, each, filter, cache;
import std.range : tee;
import std.array;
import std.exception : assumeUnique;
import core.time : MonoTime;

//import std.stdio;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONRecord;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONException : HiBONRecordException;

import tagion.dart.DARTBasic;

import tagion.basic.basic : basename;
import tagion.basic.Types : Buffer;
import tagion.crypto.Types : Pubkey;
import tagion.script.StandardRecords : SignedContract, StandardBill, Invoice, globals, Script;
import tagion.crypto.SecureNet : scramble;
import tagion.crypto.SecureInterfaceNet : SecureNet;

// import tagion.gossip.GossipNet : StdSecureNet, StdHashNet, scramble;
import tagion.basic.Message;
import tagion.utils.Miscellaneous;
import tagion.Keywords;
import tagion.script.TagionCurrency;
import tagion.communication.HiRPC;
import tagion.wallet.KeyRecover;
import tagion.wallet.WalletRecords : RecoverGenerator, DevicePIN, AccountDetails;
import tagion.wallet.WalletException : WalletException;
import tagion.basic.tagionexceptions : Check;
import tagion.crypto.Cipher;

alias check = Check!(WalletException);
alias CiphDoc = Cipher.CipherDocument;

import tagion.communication.HiRPC;

/// Function and data to recover, sign transaction and hold the account information
@safe struct SecureWallet(Net : SecureNet) {
    protected RecoverGenerator _wallet; /// Information to recover the seed-generator
    protected DevicePIN _pin; /// Information to check the Pin code

    AccountDetails account; /// Account-details holding the bills and generator
    protected SecureNet net;

    /**
     * 
     * Params:
     *   pin = Devices pin code information
     *   wallet = Infomation to recover the pin-code
     *   account =  Acount to hold bills and derivers
     */
    this(DevicePIN pin,
            RecoverGenerator wallet = RecoverGenerator.init,
            AccountDetails account = AccountDetails.init) nothrow {
        _wallet = wallet;
        _pin = pin;
        this.account = account;
    }

    this(const Document wallet_doc,
            const Document pin_doc = Document.init) {
        auto __wallet = RecoverGenerator(wallet_doc);
        DevicePIN __pin;
        if (!pin_doc.empty) {
            __pin = DevicePIN(pin_doc);
        }
        this(__pin, __wallet);
    }

    /**
     * 
     * Returns: Wallet recovery information
     */
    @nogc const(RecoverGenerator) wallet() pure const nothrow {
        return _wallet;
    }

    /**
     * Retreive the device-pin generation
     * Returns: Device PIN infomation
     */
    @nogc const(DevicePIN) pin() pure const nothrow {
        return _pin;
    }

    /**
     * 
     * Returns: The confidence of the answers
     */
    @nogc uint confidence() pure const nothrow {
        return _wallet.confidence;
    }

    /**
     * Creates a wallet from a list for questions and answers
     * Params:
     *   questions = List of question
     *   answers = List of answers
     *   confidence = Cofindence of the answers
     *   pincode = Devices pin code
     *   seed = Supplied seed
     * Returns: 
     *   Create an new wallet accouring with the input
     */
    static SecureWallet createWallet(
            scope const(string[]) questions,
    scope const(char[][]) answers,
    uint confidence,
    const(char[]) pincode,
    scope const(ubyte[]) seed = null)
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

        recover.createKey(questions, answers, confidence, seed);
        SecureWallet result;
        {
            auto R = new ubyte[net.hashSize];
            scope (exit) {
                scramble(R);
            }
            recover.findSecret(R, questions, answers);
            net.createKeyPair(R);
            auto wallet = RecoverGenerator(recover.toDoc);
            result = SecureWallet(DevicePIN.init, wallet);
            result.set_pincode(recover, R, pincode, net);

        }
        return result;
    }

    /**
     * Creates a wallet from a mnemonic
     * Params:
     *   mnemonic = generated deterministic key 
     *   pincode = Devices pin code
     * Returns: 
     *   Create an new wallet with the input
     */
    static SecureWallet createWallet(
            const(ushort[]) mnemonic,
    const(char[]) pincode)
    in {
        assert(mnemonic.length >= 12, "Mnemonic is empty");
    }
    do {
        import tagion.wallet.BIP39;

        auto net = new Net;
        auto recover = KeyRecover(net);

        //TODO: createKey with mnemonic and device id.
        // recover.createKey(mnemonic, deviceId, null);
        SecureWallet result;
        {
            auto R = bip39(mnemonic);
            scope (exit) {
                scramble(R);
            }
            //recover.findSecret(R, mnemonic);
            net.createKeyPair(R);

            auto wallet = RecoverGenerator.init; //(recover.toDoc);
            result = SecureWallet(DevicePIN.init, wallet);
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

    /**
     * Checks that the answers to the question is correct
     * Params:
     *   questions = List of questions
     *   answers = List of answers
     * Returns:
     *   True of N=confidence number of answers is correct
     */
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

    /**
     * Recover the key-pair from the quiz or the device-pincode
     * Params:
     *   questions = List of question
     *   answers = List of answers
     *   pincode = Devices pin code
     * Returns:
     *   True if the key-pair has been recovered for the quiz or the pincode
     */
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
            set_pincode(recover, R, pincode);
            net.createKeyPair(R);
            return true;
        }
        net = null;
        return false;
    }

    /**
     * Checks if the wallet contains a key-pair
     * Returns: true if the wallet is loggin
     */
    @nogc bool isLoggedin() pure const nothrow {
        pragma(msg, "fixme(cbr): Jam the net");
        return net !is null;
    }

    /**
     * Throws a WalletExceptions if the wallet is not logged in 
     */
    protected void checkLogin() pure const {
        check(isLoggedin(), "Need login first");
    }

    /**
     * Generates the key-pair from the pin code
     * Params:
     *   pincode = device pincode
     * Returns: true of the pin-code 
     */
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

    /**
     * Removes the key-pair 
     */
    void logout() pure nothrow {
        net = null;
    }

    /**
     * Checks if the pincode is correct
     * Params:
     *   pincode = device pincode
     * Returns: true if the pincode is correct
     */
    bool checkPincode(const(char[]) pincode) {
        const hashnet = new Net;
        auto recover = KeyRecover(hashnet);
        const pinhash = recover.checkHash(pincode.representation, _pin.U);
        scope R = new ubyte[hashnet.hashSize];
        _pin.recover(R, pinhash);
        return _pin.S == recover.checkHash(R);
    }

    /**
     * Check the pincode 
     * Params:
     *   pincode = current device pincode
     *   new_pincode = new device pincode
     * Returns: true of the pincode has been change succesfully
     */
    bool changePincode(const(char[]) pincode, const(char[]) new_pincode) {
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

    /**
     * Register an invoice to the wallet
     * Params:
     *   invoice = invoice to be registered
     */
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

    /**
     * Create a new invoice which can be send to a payee 
     * Params:
     *   label = Name of the invoice
     *   amount = Amount 
     *   info = Invoce information
     * Returns: The created invoice
     */
    static Invoice createInvoice(string label, TagionCurrency amount, Document info = Document.init) {
        Invoice new_invoice;
        new_invoice.name = label;
        new_invoice.amount = amount;
        new_invoice.info = info;
        return new_invoice;
    }

    /**
     * Create a payment to a list of Invoices and produces a signed-contract
     * Collect the bill need and sign them in the contract
     * Params:
     *   orders = List of invoices
     *   result = Signed payment
     * Returns: 
     */
    bool payment(const(Invoice[]) orders, ref SignedContract result) {
        checkLogin;
        const topay = orders.map!(b => b.amount).sum;

        if (topay > 0) {
            pragma(msg, "fixme(cbr): Storage fee needs to be estimated");
            const fees = globals.fees();
            const amount = topay + fees;
            StandardBill[] contract_bills;
            const enough = collect_bills(amount, contract_bills);
            if (enough) {
                const total = contract_bills.map!(b => b.value).sum;

                result.contract.inputs = contract_bills.map!(b => net.dartIndex(b.toDoc)).array;
                const rest = total - amount;
                if (rest > 0) {
                    Invoice money_back;
                    money_back.amount = rest;
                    registerInvoice(money_back);
                    result.contract.output[money_back.pkey] = rest.toDoc;
                }
                orders.each!((o) { result.contract.output[o.pkey] = o.amount.toDoc; });
                result.contract.script = Script("pay");

                immutable message = net.calcHash(result.contract.toDoc);
                auto shared_net = (() @trusted { return cast(shared) net; })();
                auto bill_net = new Net;
                // Sign all inputs
                result.signs = contract_bills
                    .filter!(b => b.owner in account.derives)
                    .map!((b) {
                        immutable tweak_code = account.derives[b.owner];
                        bill_net.derive(tweak_code, shared_net);
                        return bill_net.sign(message);
                    })
                    .array;
                return true;
            }
            result = result.init;
            return false;
        }

        return false;
    }

    /**
     * Calculates the amount which can be activate
     * Returns: the amount of available amount
     */
    TagionCurrency available_balance() const pure {
        return account.available;
    }

    /**
     * Calcutales the locked amount in the network
     * Returns: the locked amount
     */
    TagionCurrency locked_balance() const pure {
        return account.locked;
    }

    /**
     * Calcutales the total amount
     * Returns: total amount
     */
    TagionCurrency total_balance() const pure {
        return account.total;
    }

    /**
     * Clear the locked bills
     */
    @trusted
    void unlockBills() {
        account.activated.clear;
    }

    /**
     * Creates HiRPC to request an wallet update
     * Returns: The command to the the update
     */
    const(HiRPC.Sender) getRequestUpdateWallet() const {
        HiRPC hirpc;
        auto h = new HiBON;
        h = account.derives.byKey.map!(p => cast(Buffer) p);
        return hirpc.search(h);
    }

    /**
     * Collects the bills for the amount
     * Params:
     *   amount = the amount to be collected
     *   locked_bills = the list of bills
     * Returns: true if wallet has enough to pay the amount
     */
    bool collect_bills(const TagionCurrency amount, out StandardBill[] locked_bills) {
        import std.algorithm.sorting : isSorted, sort;
        import std.algorithm.iteration : cumulativeFold;
        import std.range : takeOne, tee;

        if (!account.bills.isSorted!q{a.value > b.value}) {
            account.bills.sort!q{a.value > b.value};
        }

        // Select all bills not in use
        auto none_locked = account.bills.filter!(b => !(b.owner in account.activated));

        // Check if we have enough money
        const enough = !none_locked.map!(b => b.value)
            .cumulativeFold!((a, b) => a + b)
            .filter!(a => a >= amount)
            .takeOne
            .empty;
        if (enough) {
            TagionCurrency rest = amount;
            locked_bills = none_locked.filter!(b => b.value <= rest)
                .until!(b => rest <= 0)
                .tee!((b) { rest -= b.value; account.activated[b.owner] = true; })
                .array;
            if (rest > 0) {
                // Take an extra larger bill if not enough
                StandardBill extra_bill;
                none_locked.each!(b => extra_bill = b);
                account.activated[extra_bill.owner] = true;
                locked_bills ~= extra_bill;
            }
            assert(rest > 0);
            return true;
        }
        return false;
    }

    /**
     * Update the the wallet for a request update
     * Params:
     *   receiver = response to the wallet
     * Returns: ture if the wallet was updated
     */
    @trusted
    bool setResponseUpdateWallet(const(HiRPC.Receiver) receiver) nothrow {
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

    /**
     * Calculates the amount in a list of bills
     * Params:
     *   bills = list of bills 
     * Returns: total amount
     */
    static TagionCurrency calcTotal(const(StandardBill[]) bills) pure {
        return bills.map!(b => b.value).sum;
    }

    immutable(ubyte)[] getPublicKey() {
        import std.typecons;

        const pkey = net.pubkey;
        return cast(TypedefType!Pubkey)(pkey);
    }

    struct DeriverState {
        Buffer[Pubkey] derives;
        Buffer derive_state;
        mixin HiBONRecord;
    }

    Buffer getDeriversState() {
        return this.account.derive_state;
    }

    @trusted
    const(CiphDoc) getEncrDerivers() {
        DeriverState derive_state;
        derive_state.derives = this.account.derives;
        derive_state.derive_state = this.account.derive_state;
        return Cipher.encrypt(this.net, derive_state.toDoc);
    }

    void setEncrDerivers(const(CiphDoc) cipher_doc) {
        Cipher cipher;
        const derive_state_doc = cipher.decrypt(this.net, cipher_doc); //this.net, getEncrDerivesList(
        DeriverState derive_state = DeriverState(derive_state_doc);
        this.account.derives = derive_state.derives;
        this.account.derive_state = derive_state.derive_state;
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
        const wallet_doc = SecureWallet.createWallet(dummey_questions,
                dummey_amswers, confidence, pin_code).wallet.toDoc;

        const pin_doc = SecureWallet.createWallet(
                dummey_questions,
                dummey_amswers,
                confidence,
                pin_code).pin.toDoc;

        auto secure_wallet = SecureWallet(wallet_doc, pin_doc);
        const pin_code_2 = "3434";
        { // Login test
            assert(!secure_wallet.isLoggedin);
            secure_wallet.login(pin_code);
            assert(secure_wallet.checkPincode(pin_code));
            assert(secure_wallet.isLoggedin);
            secure_wallet.logout;
            assert(secure_wallet.checkPincode(pin_code));
            assert(!secure_wallet.isLoggedin);
            secure_wallet.login(pin_code_2);
            assert(secure_wallet.checkPincode(pin_code));
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
            assert(secure_wallet.checkPincode(pin_code_2));
            assert(!secure_wallet.isLoggedin);
            secure_wallet.login(pin_code_2);
            assert(secure_wallet.isLoggedin);
        }

        const new_pincode = "7851";
        { // Fail to change pin-code
            const result = secure_wallet.changePincode(new_pincode, pin_code_2);
            assert(!result);
            assert(secure_wallet.isLoggedin);
        }

        { // Change pincode
            const result = secure_wallet.changePincode(pin_code_2, new_pincode);
            assert(result);
            assert(!secure_wallet.isLoggedin);
            secure_wallet.login(new_pincode);
            assert(secure_wallet.isLoggedin);
        }
        { // Secure wallet with mnemonic.

            const test_pin_code = "1234";
            const test_mnemonic = cast(ushort[])[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
            // Create first wallet.
            auto secure_wallet_1 = SecureWallet.createWallet(test_mnemonic, test_pin_code);
            secure_wallet_1.login(test_pin_code);
            auto pubkey_1 = secure_wallet_1.getPublicKey();
            // Create second wallet.
            auto secure_wallet_2 = SecureWallet.createWallet(test_mnemonic, test_pin_code);
            secure_wallet_2.login(test_pin_code);
            auto pubkey_2 = secure_wallet_2.getPublicKey();

            writeln("Pubkey 1 ", pubkey_1);
            writeln("Pubkey 2 ", pubkey_2);

            // assert(pubkey_1 == pubkey_2);
        }

    }

    unittest { // Test for account
        import std.stdio;
        import std.range : zip;

        auto sender_wallet = SecureWallet(DevicePIN.init, RecoverGenerator.init);
        auto net = new Net;

        { // Add SecureNet to the wallet
            immutable very_securet = "Very Secret password";
            net.generateKeyPair(very_securet);
            sender_wallet.net = net;
        }

        { // Create a number of bills in the seneder_wallet
            auto bill_amounts = [4, 1, 100, 40, 956, 42, 354, 7, 102355].map!(a => a.TGN);
            auto gene = cast(Buffer) net.calcHash("gene".representation);
            const uint epoch = 42;

            const label = "some_name";
            auto list_of_invoices = bill_amounts.map!(a => createInvoice(label, a))
                .each!(invoice => sender_wallet.registerInvoice(invoice))();

            import tagion.utils.Miscellaneous : hex;

            // Add the bulls to the account with the derive keys
            with (sender_wallet.account) {
                bills = zip(bill_amounts, derives.byKey).map!(bill_derive => StandardBill(bill_derive[0],
                epoch, bill_derive[1], gene)).array;
            }

            assert(sender_wallet.available_balance == bill_amounts.sum);
            assert(sender_wallet.total_balance == bill_amounts.sum);
            assert(sender_wallet.locked_balance == 0.TGN);
        }

        auto receiver_wallet = SecureWallet(DevicePIN.init, RecoverGenerator.init);
        { // Add securety to the receiver_wallet
            auto receiver_net = new Net;
            immutable very_securet = "Very Secret password for the receriver";
            receiver_net.generateKeyPair(very_securet);
            receiver_wallet.net = receiver_net;
        }

        pragma(msg,
                "fixme(cbr): The following test is not finished, Need to transfer to money to receiver");
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
