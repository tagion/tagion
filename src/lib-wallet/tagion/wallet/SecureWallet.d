/**
* Handles management of key-pair, account-details device-pin
*/
module tagion.wallet.SecureWallet;
@safe:
import core.time : MonoTime;
import std.algorithm;
import std.array;
import std.format;
import std.range;
import std.string : representation;
import tagion.utils.Miscellaneous;
import tagion.utils.Result;

//import std.stdio;
import tagion.basic.Types : Buffer;
import tagion.basic.basic : basename, isinit;
import tagion.crypto.Types : Pubkey;
import tagion.dart.DARTBasic;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.HiBONException : HiBONRecordException;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord : HiBONRecord;
import tagion.utils.StdTime;

// import tagion.script.prior.StandardRecords : SignedContract, globals, Script;
//import PriorStandardRecords = tagion.script.prior.StandardRecords;

import tagion.crypto.SecureInterfaceNet : SecureNet;

// import tagion.gossip.GossipNet : StdSecureNet, StdHashNet, scramble;
import tagion.Keywords;
import tagion.basic.Message;
import tagion.basic.tagionexceptions : Check;
import tagion.communication.HiRPC;
import tagion.crypto.Cipher;
import tagion.crypto.random.random;
import tagion.script.TagionCurrency;
import tagion.script.common;
import tagion.utils.Miscellaneous;
import tagion.utils.StdTime;
import tagion.wallet.AccountDetails;
import tagion.wallet.Basic : saltHash;
import tagion.wallet.KeyRecover;
import tagion.wallet.WalletException : WalletException;
import tagion.wallet.WalletRecords : DevicePIN, RecoverGenerator;

alias check = Check!(WalletException);
alias CiphDoc = Cipher.CipherDocument;

import tagion.communication.HiRPC;

/// Function and data to recover, sign transaction and hold the account information
struct SecureWallet(Net : SecureNet) {
    protected RecoverGenerator _wallet; /// Information to recover the seed-generator
    protected DevicePIN _pin; /// Information to check the Pin code

    AccountDetails account; /// Account-details holding the bills and generator
    protected SecureNet _net;

    const(SecureNet) net() const pure nothrow @nogc {
        return _net;
    }

    version (NET_HACK) {
        void set_net(SecureNet copy_net) {
            this._net = copy_net;
        }

    }

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
     * Returns: 
     *   Create an new wallet accouring with the input
     */
    this(
            scope const(string[]) questions,
            scope const(char[][]) answers,
            uint confidence,
            const(char[]) pincode)
    in (questions.length is answers.length, "Amount of questions should be same as answers")
    do {
        check(questions.length > 3, "Minimal amount of answers is 4");
        _net = new Net();
        //        auto hashnet = new StdHashNet;
        auto recover = KeyRecover(_net);

        if (confidence == questions.length) {
            pragma(msg, "fixme(cbr): Due to some bug in KeyRecover");
            // Due to some bug in KeyRecover
            confidence--;
        }

        recover.createKey(questions, answers, confidence);
        auto R = new ubyte[_net.hashSize];
        scope (exit) {
            R[] = 0;
        }
        recover.findSecret(R, questions, answers);
        _net.createKeyPair(R);
        _wallet = RecoverGenerator(recover.toDoc);
        set_pincode(R, pincode);
    }

    this(scope const(ubyte)[][] answers, uint confidence, const(char[]) pincode = null) {

        _net = new Net();
        auto recover = KeyRecover(_net);
        if (confidence == answers.length) {
            confidence--;
        }
        recover.createKey(answers, confidence);
        auto R = new ubyte[_net.hashSize];
        scope (exit) {
            R[] = 0;
        }
        recover.quizSeed(R, answers, confidence);
        _net.createKeyPair(R);
        _wallet = RecoverGenerator(recover.toDoc);
        if (!pincode.empty) {
            set_pincode(R, pincode);
        }

    }

    this(
            scope const(char[]) passphrase,
            scope const(char[]) pincode,
            scope const(char[]) salt = null) {
        _net = new Net;
        enum size_of_privkey = 32;
        ubyte[] R;
        scope (exit) {
            _wallet.S = _net.saltHash(R);
            set_pincode(R, pincode);
            R[] = 0;
        }
        _net.generateKeyPair(passphrase, salt,
                (scope const(ubyte[]) data) { R = data[0 .. size_of_privkey].dup; });
    }

    protected void set_pincode(
            scope const(ubyte[]) R,
            scope const(char[]) pincode) scope
    in (!_net.isinit)
    do {
        auto seed = new ubyte[_net.hashSize];
        getRandom(seed);
        _pin.setPin(_net, R, pincode.representation, seed.idup);
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
    in (questions.length is answers.length, "Amount of questions should be same as answers")
    do {
        _net = new Net;
        auto recover = KeyRecover(_net, _wallet);
        scope R = new ubyte[_net.hashSize];
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
    bool recover(
            const(string[]) questions,
            const(char[][]) answers,
            const(char[]) pincode)
    in (questions.length is answers.length, "Amount of questions should be same as answers")
    do {
        _net = new Net;
        auto recover = KeyRecover(_net, _wallet);
        auto R = new ubyte[_net.hashSize];
        scope (exit) {
            R[] = 0;
        }
        const result = recover.findSecret(R, questions, answers);
        if (result) {
            set_pincode(R, pincode);
            _net.createKeyPair(R);
            return true;
        }
        _net = null;
        return false;
    }

    bool recover(Buffer[] A, const(char[]) pincode = null) {
        _net = new Net;
        auto recover = KeyRecover(_net, _wallet);
        auto R = new ubyte[_net.hashSize];
        scope (exit) {
            R[] = 0;
        }
        const result = recover.findSecret(R, A);
        if (result) {
            if (!pincode.empty) {
                set_pincode(R, pincode);

            }
            _net.createKeyPair(R);
            return true;
        }
        _net = null;
        return false;
    }
    /**
     * Checks if the wallet contains a key-pair
     * Returns: true if the wallet is loggin
     */
    @nogc bool isLoggedin() pure const nothrow {
        return _net !is null;
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
            auto login_net = new Net;
            auto R = new ubyte[login_net.hashSize];
            scope (exit) {
                R[] = 0;
            }
            const recovered = _pin.recover(login_net, R, pincode.representation);
            if (recovered) {
                login_net.createKeyPair(R);
                _net = login_net;
                return true;
            }
        }
        return false;
    }

    /**
     * Removes the key-pair 
     */
    void logout() pure nothrow {
        _net = null;
    }

    /**
     * Checks if the pincode is correct
     * Params:
     *   pincode = device pincode
     * Returns: true if the pincode is correct
     */
    bool checkPincode(const(char[]) pincode) {
        const hashnet = (_net.isinit) ? new Net : _net;

        scope R = new ubyte[hashnet.hashSize];
        scope (exit) {
            R[] = 0;
        }
        _pin.recover(hashnet, R, pincode.representation);
        return _pin.S == hashnet.saltHash(R);
    }

    /**
     * Check the pincode 
     * Params:
     *   pincode = current device pincode
     *   new_pincode = new device pincode
     * Returns: true of the pincode has been change succesfully
     */
    bool changePincode(const(char[]) pincode, const(char[]) new_pincode) {
        check(!_net.isinit, "Key pair has not been created");
        auto R = new ubyte[_net.hashSize];
        _pin.recover(_net, R, pincode.representation);
        if (_pin.S == _net.saltHash(R)) {
            set_pincode(R, new_pincode);
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
        account.derive_state = _net.HMAC(account.derive_state ~ _net.pubkey);
        auto pkey = _net.derivePubkey(account.derive_state);
        invoice.pkey = derivePubkey;
        account.derivers[invoice.pkey] = account.derive_state;
        account.requested_invoices ~= invoice;
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

    Pubkey derivePubkey() {
        checkLogin;
        account.derive_state = _net.HMAC(account.derive_state ~ _net.pubkey);
        return _net.derivePubkey(account.derive_state);
    }

    TagionBill[] invoices_to_bills(const(Invoice[]) orders) {
        Buffer getNonce() {
            scope nonce = new ubyte[4];
            getRandom(nonce);
            return nonce.idup;
        }

        return orders.map!((order) => TagionBill(order.amount, currentTime, order.pkey, getNonce)).array;
    }

    /**
     * Create a payment to a list of Invoices and produces a signed-contract
     * Collect the bill need and sign them in the contract
     * Params:
     *   orders = List of invoices
     *   result = Signed payment
     * Returns: 
     */
    Result!bool payment(const(Invoice[]) orders, ref SignedContract signed_contract, out TagionCurrency fees) nothrow {
        import tagion.utils.StdTime;

        try {
            checkLogin;
            auto bills = invoices_to_bills(orders);
            return createPayment(bills, signed_contract, fees);
        }
        catch (Exception e) {
            return Result!bool(e);
        }
        return result(true);
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
    const(HiRPC.Sender) getRequestUpdateWallet(HiRPC hirpc = HiRPC(null)) const {
        auto h = new HiBON;
        h = account.derivers.byKey.map!(p => cast(Buffer) p);
        return hirpc.search(h);
    }

    const(DARTIndex[]) billIndexes(const(TagionBill)[] bills) const {
        return bills
            .map!(bill => net.dartIndex(bill))
            .array;
    }

    const(HiRPC.Sender) getRequestCheckWallet(
            HiRPC hirpc = HiRPC(null),
            const(TagionBill)[] to_check = null)
    const {
        import tagion.dart.DARTcrud;

        if (to_check is null) {
            to_check = account.bills ~ account.requested.values;
        }
        return dartCheckRead(billIndexes(to_check), hirpc);

    }

    const(SecureNet[]) collectNets(const(TagionBill[]) bills) {
        return bills
            .map!(bill => bill.owner in account.derivers)
            .map!((deriver) => (deriver is null) ? _net.init : _net.derive(*deriver))
            .array;
    }
    /**
     * Collects the bills for the amount
     * Params:
     *   amount = the amount to be collected
     *   locked_bills = the list of bills
     * Returns: true if wallet has enough to pay the amount
     */
    private bool collect_bills(const TagionCurrency amount, out TagionBill[] locked_bills) {
        import std.algorithm;

        // import std.algorithm.sorting : isSorted, sort;
        // import std.algorithm.iteration : cumulativeFold;
        import std.range : takeOne, tee;
        import std.stdio;

        if (!account.bills.isSorted!q{a.value > b.value}) {
            account.bills.sort!q{a.value > b.value};
        }

        // Select all bills not in use
        auto none_locked = account.bills.filter!(b => !(b.owner in account.activated)).array;

        const enough = !none_locked
            .map!(b => b.value)
            .cumulativeFold!((a, b) => a + b)
            .filter!(a => a >= amount)
            .takeOne
            .empty;
        if (enough) {
            TagionCurrency rest = amount;
            locked_bills = none_locked
                .filter!(b => b.value <= rest) // take all bills smaller than the rest
                .until!(b => rest <= 0) // do it until the rest is smaller than or equal to zero
                .tee!((b) => rest -= b.value) // subtract their values from the rest
                .array;

            // Check if there is any remaining rest
            if (rest >= 0) {
                TagionBill extra_bill;
                // Find an appropriate extra_bill
                auto extra_bills = none_locked
                    .filter!(b => !locked_bills.canFind(b) && b.value >= rest); // Only consider bills with enough value
                if (!extra_bills.empty) {
                    extra_bill = extra_bills.front; // Select the first appropriate bill
                    locked_bills ~= extra_bill;
                }
            }
            return true;
        }
        return false;
    }

    void lock_bills(const(TagionBill[]) locked_bills) {
        locked_bills.each!(b => account.activated[b.owner] = true);
    }

    bool setResponseCheckRead(const(HiRPC.Receiver) receiver) {
        import tagion.dart.DART;

        if (!receiver.isResponse) {
            return false;
        }

        auto not_in_dart = receiver.response.result[DART.Params.dart_indices].get!Document[].map!(d => d.get!Buffer);

        foreach (not_found; not_in_dart) {
            const bill_index = account.bills
                .countUntil!(bill => net.dartIndex(bill) == not_found);

            if (bill_index >= 0) {

                auto used_bill = account.bills[bill_index];
                account.used_bills ~= used_bill;
                account.bills = account.bills.remove(bill_index);
                if (used_bill.owner in account.activated) {
                    account.activated.remove(used_bill.owner);
                }
            }
        }
        foreach (request_bill; account.requested.byValue.array.dup) {
            if (!not_in_dart.canFind(net.dartIndex(request_bill))) {
                account.bills ~= request_bill;
                account.requested.remove(request_bill.owner);
            }
        }
        return true;
    }
    /**
     * Update the the wallet for a request update
     * Params:
     *   receiver = response to the wallet
     * Returns: ture if the wallet was updated
     */
    @trusted
    bool setResponseUpdateWallet(const(HiRPC.Receiver) receiver) nothrow {
        import std.exception : assumeWontThrow;
        import tagion.hibon.HiBONtoText;

        if (!receiver.isResponse) {
            return false;
        }

        auto found_bills = assumeWontThrow(receiver.response
                .result[]
                .map!(e => TagionBill(e.get!Document))
                .array);

        foreach (b; found_bills) {
            if (b.owner !in account.derivers) {
                import std.stdio;

                assumeWontThrow(writefln("Error, could not pubkey %(%02x%) in derivers", b.owner));
                return false;
            }
        }

        foreach (found; found_bills) {
            if (!account.bills.canFind(found)) {
                account.bills ~= found;
            }
            account.requested.remove(found.owner);

            const invoice_index = account.requested_invoices
                .countUntil!(invoice => invoice.pkey == found.owner);

            if (invoice_index >= 0) {
                account.requested_invoices = account.requested_invoices.remove(invoice_index);
            }

        }

        auto locked_pkeys = account.activated
            .byKeyValue
            .filter!(a => a.value == true)
            .map!(a => a.key)
            .array;

        auto found_owners = found_bills.map!(found => found.owner).array;
        foreach (pkey; locked_pkeys) {
            if (!(found_owners.canFind(pkey))) {
                account.activated.remove(pkey);
                auto bill_index = account.bills.countUntil!(b => b.owner == pkey);
                if (bill_index >= 0) {
                    account.bills = account.bills.remove(bill_index);
                }
            }
        }

        // account.activated = new_activated;

        // go through the locked bills

        return true;
    }

    Result!bool getFee(const(TagionBill)[] to_pay, out TagionCurrency fees, bool print = false) nothrow {
        import tagion.script.Currency : totalAmount;
        import tagion.script.execute;

        try {
            PayScript pay_script;
            pay_script.outputs = to_pay;
            TagionBill[] collected_bills;
            TagionCurrency amount_remainder = 0.TGN;
            size_t previous_bill_count = size_t.max;

            const amount_to_pay = pay_script.outputs
                .map!(bill => bill.value)
                .totalAmount;
            const available_wallet_amount = available_balance();

            do {
                collected_bills.length = 0;

                const amount_to_collect = amount_to_pay + (-1 * (amount_remainder)) + fees;
                check(amount_to_collect < available_wallet_amount, "Amount is too big with fees");

                const can_pay = collect_bills(amount_to_collect, collected_bills);

                if (collected_bills.length == previous_bill_count) {
                    return result(false);
                }

                check(can_pay, format("Is unable to pay the amount %10.6fTGN available %10.6fTGN", amount_to_pay.value, available_balance
                        .value));
                const total_collected_amount = collected_bills
                    .map!(bill => bill.value)
                    .totalAmount;
                fees = ContractExecution.billFees(
                        collected_bills.map!(bill => bill.toDoc),
                        pay_script.outputs.map!(bill => bill.toDoc),
                        snavs_byte_fee);
                amount_remainder = total_collected_amount - amount_to_pay - fees;

                previous_bill_count = collected_bills.length;
            }
            while (amount_remainder < 0);
        }
        catch (Exception e) {
            return Result!bool(e);
        }
        return result(true);
    }

    Result!bool getFee(const(Invoice[]) orders, out TagionCurrency fees) nothrow {
        import std.exception;
        import tagion.utils.StdTime;

        auto bills = assumeWontThrow(orders.map!((order) => TagionBill(order.amount, currentTime, order.pkey, Buffer.init))
                .array);
        return getFee(bills, fees);
    }

    static immutable dummy_pubkey = Pubkey(new ubyte[33]);
    static immutable dummy_nonce = new ubyte[4];
    static immutable dummy_time = sdt_t(long.max);

    Result!bool getFee(TagionCurrency amount, out TagionCurrency fees) nothrow {
        auto bill = TagionBill(amount, dummy_time, dummy_pubkey, dummy_nonce);
        return getFee([bill], fees);
    }

    // stupid function for testing
    Result!bool createNFT(
            Document nft_data,
            ref SignedContract signed_contract) {
        import tagion.script.execute;
        import tagion.script.standardnames;

        try {
            HiBON dummy_input = new HiBON;
            dummy_input[StdNames.owner] = net.pubkey;
            dummy_input["NFT"] = nft_data;
            Document[] inputs;

            inputs ~= Document(dummy_input);
            SecureNet[] nets;
            nets ~= (() @trusted => cast(SecureNet) net)();

            signed_contract = sign(
                    nets,
                    inputs,
                    null,
                    Document.init);
        }
        catch (Exception e) {
            return Result!bool(e);
        }
        return result(true);
    }

    enum long snavs_byte_fee = 100;
    Result!bool createPayment(const(TagionBill)[] to_pay, ref SignedContract signed_contract, out TagionCurrency fees, bool print = false) nothrow {
        import tagion.hibon.HiBONtoText;
        import tagion.script.Currency : totalAmount;
        import tagion.script.execute;

        try {
            PayScript pay_script;
            pay_script.outputs = to_pay;
            TagionBill[] collected_bills;
            TagionCurrency amount_remainder = 0.TGN;
            size_t previous_bill_count = size_t.max;

            const amount_to_pay = pay_script.outputs
                .map!(bill => bill.value)
                .totalAmount;
            check(amount_to_pay < available_balance, "The amount requested for payment should be smaller than the available balance");

            do {
                collected_bills.length = 0;
                const amount_to_collect = amount_to_pay + (-1 * (amount_remainder)) + fees;
                const can_pay = collect_bills(amount_to_collect, collected_bills);
                if (collected_bills.length == previous_bill_count || collected_bills.length == 0) {
                    return result(false);
                }
                check(can_pay, format("Is unable to pay the amount %10.6fTGN available %10.6fTGN",
                        amount_to_pay.value,
                        available_balance.value));
                const total_collected_amount = collected_bills
                    .map!(bill => bill.value)
                    .totalAmount;

                if (print) {
                    import std.stdio;

                    writefln("calculated fee=%s", ContractExecution.billFees(
                            collected_bills.map!(bill => bill.toDoc),
                            pay_script.outputs.map!(bill => bill.toDoc),
                            snavs_byte_fee)
                    );
                }
                fees = ContractExecution.billFees(
                        collected_bills.map!(bill => bill.toDoc),
                        pay_script.outputs.map!(bill => bill.toDoc),
                        snavs_byte_fee);
                amount_remainder = total_collected_amount - amount_to_pay - fees;
                previous_bill_count = collected_bills.length;

            }
            while (amount_remainder < 0);

            const nets = collectNets(collected_bills);
            check(nets.all!(net => net !is net.init), format("Missing deriver of some of the bills length=%s", collected_bills
                    .length));
            if (amount_remainder != 0) {
                const bill_remain = requestBill(amount_remainder);
                pay_script.outputs ~= bill_remain;
            }
            lock_bills(collected_bills);
            check(nets.length == collected_bills.length, format("number of bills does not match number of signatures nets %s, collected_bills %s", nets
                    .length, collected_bills.length));

            signed_contract = sign(
                    nets,
                    collected_bills.map!(bill => bill.toDoc)
                    .array,
                    null,
                    pay_script.toDoc);
        }
        catch (Exception e) {
            return Result!bool(e);
        }
        return result(true);
    }
    /**
     * Calculates the amount in a list of bills
     * Params:
     *   bills = list of bills 
     * Returns: total amount
     */
    static TagionCurrency calcTotal(const(TagionBill[]) bills) pure {
        return bills.map!(b => b.value).sum;
    }

    Buffer getPublicKey() {
        import std.typecons;

        const pkey = _net.pubkey;
        return cast(TypedefType!Pubkey)(pkey);
    }

    struct DeriverState {
        Buffer[Pubkey] derivers;
        Buffer derive_state;
        mixin HiBONRecord;
    }

    Buffer getDeriversState() {
        return this.account.derive_state;
    }

    TagionBill requestBill(TagionCurrency amount, sdt_t bill_time = currentTime) {
        check(amount > 0.TGN, format("Requested bill should have a positive value and not %10.6fTGN", amount.value));
        TagionBill bill;
        bill.value = amount;
        bill.time = bill_time;
        auto nonce = new ubyte[4];
        getRandom(nonce);
        bill.nonce = nonce.idup;
        auto derive = _net.HMAC(bill.toDoc.serialize);
        bill.owner = _net.derivePubkey(derive);
        //account.bills ~= bill;
        account.requestBill(bill, derive);
        return bill;
    }

    TagionBill addBill(const Document doc) {
        return account.add_bill(doc);
    }

    bool addBill(TagionBill bill) {
        return account.add_bill(bill);
    }

    @trusted
    const(CiphDoc) getEncrDerivers() {
        DeriverState derive_state;
        derive_state.derivers = this.account.derivers;
        derive_state.derive_state = this.account.derive_state;
        return Cipher.encrypt(this._net, derive_state.toDoc);
    }

    void setEncrDerivers(const(CiphDoc) cipher_doc) {
        Cipher cipher;
        const derive_state_doc = cipher.decrypt(this._net, cipher_doc);
        DeriverState derive_state = DeriverState(derive_state_doc);
        this.account.derivers = derive_state.derivers;
        this.account.derive_state = derive_state.derive_state;
    }

    @trusted
    const(CiphDoc) getEncrAccount() {
        return Cipher.encrypt(this._net, this.account.toDoc);
    }

    void setEncrAccount(const(CiphDoc) cipher_doc) {
        Cipher cipher;
        const account_doc = cipher.decrypt(this._net, cipher_doc);
        this.account = AccountDetails(account_doc);
    }

    unittest {
        import std.format;
        import std.range : iota;
        import std.stdio;
        import tagion.hibon.HiBONJSON;

        const good_pin_code = "1234";

        // Create a new Wallet
        enum {
            num_of_questions = 5,
            confidence = 3
        }
        const dummey_questions = num_of_questions.iota.map!(i => format("What %s", i)).array;
        const dummey_amswers = num_of_questions.iota.map!(i => format("A %s", i)).array;
        const wallet_doc = SecureWallet(dummey_questions,
                dummey_amswers, confidence, good_pin_code).wallet.toDoc;

        const pin_doc = SecureWallet(
                dummey_questions,
                dummey_amswers,
                confidence,
                good_pin_code).pin.toDoc;

        auto secure_wallet = SecureWallet(wallet_doc, pin_doc);
        const bad_pin_code = "3434";
        { // Login test
            assert(!secure_wallet.isLoggedin);
            secure_wallet.login(good_pin_code);
            assert(secure_wallet.checkPincode(good_pin_code));
            assert(secure_wallet.isLoggedin);
            secure_wallet.logout;
            assert(secure_wallet.checkPincode(good_pin_code));
            assert(!secure_wallet.isLoggedin);
            secure_wallet.login(bad_pin_code);
            assert(!secure_wallet.isLoggedin);
            // Check login pin
            assert(secure_wallet.checkPincode(good_pin_code));
            assert(!secure_wallet.isLoggedin);
            // Login again
            assert(secure_wallet.login(good_pin_code));
            assert(secure_wallet.isLoggedin);
        }

        const pin_code_2 = "4217";
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

    }

    unittest { // Test for account
        import std.range : zip;
        import tagion.utils.Miscellaneous;

        auto sender_wallet = SecureWallet(DevicePIN.init, RecoverGenerator.init);
        auto _net = new Net;

        { // Add SecureNet to the wallet
            immutable very_securet = "Very Secret password";
            _net.generateKeyPair(very_securet);
            sender_wallet._net = _net;
        }

        { // Create a number of bills in the seneder_wallet
            auto bill_amounts = [4, 1, 100, 40, 956, 42, 354, 7, 102355].map!(a => a.TGN);
            const uint epoch = 42;

            const label = "some_name";
            auto list_of_invoices = bill_amounts.map!(a => createInvoice(label, a))
                .each!(invoice => sender_wallet.registerInvoice(invoice))();

            // Add the bulls to the account with the derive keys
            with (sender_wallet.account) {
                bills = zip(bill_amounts, derivers.byKey).map!(bill_derive => TagionBill(
                        bill_derive[0],
                        currentTime,
                        bill_derive[1],
                        Buffer.init)).array;
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
            receiver_wallet._net = receiver_net;
        }

        pragma(msg, "fixme(cbr): The following test is not finished, Need to transfer to money to receiver");
        SignedContract contract_1;
        { // The receiver_wallet creates an invoice to the sender_wallet
            auto invoice = SecureWallet.createInvoice("To sender 1", 13.TGN);
            receiver_wallet.registerInvoice(invoice);
            TagionCurrency fees;
            // Give the invoice to the sender_wallet and create payment
            TagionCurrency expected_fee;
            sender_wallet.getFee([invoice], expected_fee);

            sender_wallet.payment([invoice], contract_1, fees);
            pragma(msg, "fixme: fix snavs for this to work");
            version (none) {
                assert(expected_fee == fees, "fee for get fee and expected fee should be the same");
            }
        }

        SignedContract contract_2;
        { // The receiver_wallet creates an invoice to the sender_wallet
            auto invoice = SecureWallet.createInvoice("To sender 2", 53.TGN);
            receiver_wallet.registerInvoice(invoice);
            TagionCurrency fees;
            // Give the invoice to the sender_wallet and create payment
            sender_wallet.payment([invoice], contract_2, fees);
        }
    }
}

version (unittest) {
    import std.exception;
    import tagion.crypto.SecureNet;

    //    import std.stdio;
    import tagion.script.execute;

    alias StdSecureWallet = SecureWallet!StdSecureNet;

}

unittest {
    auto wallet = StdSecureWallet("secret", "1234");
    const bill1 = wallet.requestBill(1000.TGN);
    wallet.addBill(bill1);
    assert(wallet.available_balance == 1000.TGN);
    const bill_to_pay = wallet.requestBill(1000.TGN);
    SignedContract signed_contract;
    TagionCurrency fees;
    assertThrown(wallet.createPayment([bill_to_pay], signed_contract, fees).get);

    const smaller_bill = wallet.requestBill(999.TGN);

    SignedContract signed_contract1;
    TagionCurrency fees1;
    assertThrown(wallet.createPayment([bill_to_pay], signed_contract1, fees1).get);
}

unittest {
    import std.range;

    //pay invoice to yourself with multiple bills as outputs
    auto wallet = StdSecureWallet("secret", "1234");
    const bill1 = wallet.requestBill(1000.TGN);
    wallet.addBill(bill1);

    auto invoice_to_pay = wallet.createInvoice("wowo", 10.TGN);
    auto invoice_to_pay2 = wallet.createInvoice("wowo2", 10.TGN);
    wallet.registerInvoice(invoice_to_pay);
    wallet.registerInvoice(invoice_to_pay2);

    SignedContract signed_contract;
    TagionCurrency fees;

    TagionBill[] bills = wallet.invoices_to_bills([invoice_to_pay, invoice_to_pay2]);
    wallet.createPayment(bills, signed_contract, fees);
    HiRPC hirpc = HiRPC(null);

    assert(wallet.account.activated.byValue.filter!(b => b == true).walkLength == 1, "should have one locked bill");
    assert(wallet.locked_balance == 1000.TGN);
    const req = wallet.getRequestUpdateWallet;
    const receiver = hirpc.receive(req.toDoc);

    const number_of_bills = receiver.method.params[].array.length;
    assert(number_of_bills == 4, format("should contain three public keys had %s", number_of_bills));

    // create the response containing the two output bills without the original locked bill.
    HiBON params = new HiBON;

    import std.stdio;
    import tagion.hibon.HiBONJSON;

    TagionBill[] bills_in_dart = bills ~ wallet.account.requested.byValue.array;
    foreach (i, bill; bills_in_dart) {
        params[i] = bill.toHiBON;
    }
    auto dart_response = hirpc.result(receiver, Document(params)).toDoc;
    const received = hirpc.receive(dart_response);

    wallet.setResponseUpdateWallet(received);

    auto should_have = wallet.calcTotal(bills_in_dart);
    assert(should_have == wallet.total_balance, format("should have %s had %s", should_have, wallet.total_balance));

}

unittest {
    import std.range;

    // pay invoice to yourself.
    auto wallet = StdSecureWallet("secret", "1234");
    const bill1 = wallet.requestBill(1000.TGN);
    wallet.addBill(bill1);

    auto invoice_to_pay = wallet.createInvoice("wowo", 10.TGN);
    wallet.registerInvoice(invoice_to_pay);

    SignedContract signed_contract;
    TagionCurrency fees;

    TagionBill[] bills = wallet.invoices_to_bills([invoice_to_pay]);
    wallet.createPayment(bills, signed_contract, fees);
    HiRPC hirpc = HiRPC(null);

    assert(wallet.account.activated.byValue.filter!(b => b == true).walkLength == 1, "should have one locked bill");
    assert(wallet.locked_balance == 1000.TGN);
    const req = wallet.getRequestUpdateWallet;
    const receiver = hirpc.receive(req.toDoc);

    const number_of_bills = receiver.method.params[].array.length;
    assert(number_of_bills == 3, format("should contain three public keys had %s", number_of_bills));

    // create the response containing the two output bills without the original locked bill.
    HiBON params = new HiBON;

    import std.stdio;
    import tagion.hibon.HiBONJSON;

    TagionBill[] bills_in_dart = bills ~ wallet.account.requested.byValue.array;
    foreach (i, bill; bills_in_dart) {
        params[i] = bill.toHiBON;
    }
    auto dart_response = hirpc.result(receiver, Document(params)).toDoc;
    const received = hirpc.receive(dart_response);

    wallet.setResponseUpdateWallet(received);

    auto should_have = wallet.calcTotal(bills_in_dart);
    assert(should_have == wallet.total_balance, format("should have %s had %s", should_have, wallet.total_balance));

}

unittest {
    // check get fee greater than user amount

    auto wallet1 = StdSecureWallet("some words", "1234");
    const bill1 = wallet1.requestBill(1000.TGN);
    wallet1.addBill(bill1);

    TagionCurrency fees;
    const res = wallet1.getFee(10_000.TGN, fees);

    // should fail
    assert(res.value == false);
}

unittest {

    import std.algorithm;
    import std.exception;
    import std.stdio;
    import tagion.hibon.HiBONJSON;

    auto wallet1 = StdSecureWallet("some words", "1234");
    auto wallet2 = StdSecureWallet("some words2", "4321");
    const bill1 = wallet1.requestBill(1000.TGN);
    const bill2 = wallet1.requestBill(2000.TGN);

    wallet1.addBill(bill1);
    wallet1.addBill(bill2);
    assert(wallet1.available_balance == 3000.TGN);

    auto payment_request = wallet2.requestBill(1500.TGN);
    auto too_big_request = wallet2.requestBill(10000.TGN);

    TagionCurrency expected_fee;
    assert(!wallet1.getFee([too_big_request], expected_fee).value, "should throw on too big value");
    assert(!wallet1.getFee(10000.TGN, expected_fee).value, "should throw on too big value");
    assert(wallet1.getFee(100.TGN, expected_fee).value, "should be able to pay amount");

    assert(wallet1.getFee([payment_request], expected_fee).value, "error in getFee");
    assert(wallet1.available_balance == 3000.TGN, "getfee should not change any balances");

    SignedContract signed_contract;
    TagionCurrency fee;
    assert(wallet1.createPayment([payment_request], signed_contract, fee).value, "error creating payment");

    assert(fee == expected_fee, format("fees not the same %s, %s", fee, expected_fee));

    assert(signed_contract.contract.inputs.uniq.array.length == signed_contract.contract.inputs.length, "signed contract inputs invalid");
}

unittest {

    import std.algorithm;
    import std.exception;
    import std.stdio;
    import tagion.hibon.HiBONJSON;

    auto wallet1 = StdSecureWallet("some words", "1234");
    auto wallet2 = StdSecureWallet("some words2", "4321");
    const bill1 = wallet1.requestBill(1000.TGN);
    const bill2 = wallet1.requestBill(2000.TGN);

    wallet1.addBill(bill1);
    wallet1.addBill(bill2);
    assert(wallet1.available_balance == 3000.TGN);

    // create a payment request that is the same size as one bill that the wallet has
    auto payment_request = wallet2.requestBill(1000.TGN);

    SignedContract signed_contract;
    TagionCurrency fee;
    auto p = wallet1.createPayment([payment_request], signed_contract, fee);
    assert(p.value, format("ERROR: %s %s", p.value, p.msg));

    assert(signed_contract.contract.inputs.uniq.array.length == signed_contract.contract.inputs.length,
            "signed contract inputs invalid");
}

unittest {
    auto wallet1 = StdSecureWallet("some words", "1234");
    const bill1 = wallet1.requestBill(1000.TGN);
    const bill2 = wallet1.requestBill(2000.TGN);
    const bill3 = wallet1.requestBill(3000.TGN);
    assert(wallet1.account.requested.length == 3);

    assert(wallet1.account.bills.length == 0);
    wallet1.account.add_bill(bill1);
    assert(wallet1.account.bills.length == 1);
    assert(wallet1.total_balance == 1000.TGN);
    assert(wallet1.available_balance == 1000.TGN);
    assert(wallet1.locked_balance == 0.TGN);

    {
        TagionBill[] locked_bills;
        const can_collect = wallet1.collect_bills(1200.TGN, locked_bills);
        assert(!can_collect);
        assert(locked_bills.length == 0);
    }

    {
        TagionBill[] locked_bills;
        const can_collect = wallet1.collect_bills(500.TGN, locked_bills);
        assert(can_collect);
        assert(locked_bills.length == 1);
        const nets = wallet1.collectNets(locked_bills);

        assert(nets.length == nets.length);
        assert(nets.all!(net => net !is net.init));
    }

    auto wallet2 = StdSecureWallet("some other words", "4321");
    const w2_bill1 = wallet2.requestBill(1500.TGN);
    { /// faild not enouch money
        SignedContract signed_contract;
        TagionCurrency fees;
        const result = wallet1.createPayment([w2_bill1], signed_contract, fees);
        assert(!result);
    }
    wallet1.account.add_bill(bill2);
    assert(wallet1.available_balance == 3000.TGN);

    pragma(msg, "fixme: remove snavs_byte_fee for this to work");
    version (none) { /// succces payment

        import std.stdio;

        SignedContract signed_contract;
        TagionCurrency fees;
        const bills_to_pay = [w2_bill1];
        writefln("PAY ===");
        const can_pay = wallet1.createPayment(bills_to_pay, signed_contract, fees);

        const pay_script = PayScript(signed_contract.contract.script);
        writefln("----- -----");

        auto input_docs = [bill1, bill2].map!(bill => bill.toDoc);
        auto output_docs = pay_script.outputs.map!(bill => bill.toDoc);

        const expected_fees = ContractExecution.billFees(
                input_docs,
                output_docs,
                0
        );

        writefln("%s %s", bills_to_pay.map!(bill => bill.toDoc.full_size), pay_script.outputs.map!(bill => bill.toDoc
                .full_size));
        writefln("fees=%s expected_fees=%s", fees, expected_fees);
        assert(fees == expected_fees);
        assert(wallet1.total_balance == 3000.TGN);
        assert(wallet1.locked_balance == 3000.TGN);
        assert(wallet1.available_balance == 0.TGN);

    }

}

// check that the public key is deterministic
unittest {
    const words = "long second damp volcano laptop friend noble citizen hip cake safe gown";
    const pin = "1234";

    auto wallet1 = StdSecureWallet(words, pin);
    auto wallet2 = StdSecureWallet(words, pin);
    assert(wallet1.getPublicKey == wallet2.getPublicKey, "should have generated the same publickey");

    auto wallet3 = StdSecureWallet("Some other words", pin);
    assert(wallet1.getPublicKey != wallet3.getPublicKey);

    auto wallet4 = StdSecureWallet(words, "5432");
    assert(wallet1.getPublicKey == wallet4.getPublicKey, "should have generated the same publickey");
}

// check pubkey is the same after login/logout
unittest {
    import std.stdio;

    const words = "long second damp volcano laptop friend noble citizen hip cake safe gown";
    const pin = "1234";

    auto wallet1 = StdSecureWallet(words, pin);
    auto pkey_before = wallet1.getPublicKey.idup;
    wallet1.logout;
    auto pindup = pin.dup;
    assert(wallet1.login(pindup));
    auto pkey_after = wallet1.getPublicKey;
    assert(pkey_before == pkey_after, "public key not the same after login/logout");
}

// fee amount
unittest {
    auto wallet1 = StdSecureWallet("some words", "1234");
    const bill1 = wallet1.requestBill(1000.TGN);
    const bill2 = wallet1.requestBill(1000.TGN);
    const bill3 = wallet1.requestBill(1000.TGN);
    assert(wallet1.account.requested.length == 3);
    assert(wallet1.account.bills.length == 0);
    wallet1.account.add_bill(bill1);
    wallet1.account.add_bill(bill2);
    wallet1.account.add_bill(bill3);
    assert(wallet1.account.bills.length == 3);

    const to_pay = [TagionBill(2000.TGN, sdt_t.init, Pubkey([1, 2, 3, 4]), Buffer.init)];
    const to_pay2 = [TagionBill(1999.TGN, sdt_t.init, Pubkey([1, 2, 3, 4]), Buffer.init)];

    TagionCurrency fees;
    const res = wallet1.getFee(to_pay, fees);
    check(res.value == true, "Wallet should be able to pay 2000 TGN");
    const res2 = wallet1.getFee(to_pay2, fees, true);
    check(res2.value == true, format("Wallet should be able to pay 1999 TGN fee: %s", fees));

    SignedContract signed_contract;

    const can_pay = wallet1.createPayment(to_pay2, signed_contract, fees);
    check(can_pay.value == true, "should be able to create payment");
}

unittest {
    auto wallet1 = StdSecureWallet("some words", "1234");
    foreach (i; 0 .. 20) {
        const bill = wallet1.requestBill(1000.TGN);
        wallet1.account.add_bill(bill);
    }
    // we pay 10000 should produce negative fee
    const to_pay = [TagionBill(10_000.TGN, sdt_t.init, Pubkey([1, 2, 3, 4]), Buffer.init)];

    TagionCurrency get_fees;
    const res = wallet1.getFee(to_pay, get_fees);
    check(res.value == true, "should be able to pay 10000 tgn");
    TagionCurrency actual_fees;

    SignedContract signed_contract;
    const can_pay = wallet1.createPayment(to_pay, signed_contract, actual_fees, true);
    check(can_pay.value == true, "should be able to create payment");
    check(get_fees == actual_fees, "the fee should be the same");
    check(actual_fees < 0, "should be a negatvie fee due to the contract being positive");
}

// amount test
unittest {
    import std.stdio;

    auto wallet1 = StdSecureWallet("some words", "1234");
    const bill1 = wallet1.requestBill(10000.TGN);
    const bill2 = wallet1.requestBill(10000.TGN);
    const bill3 = wallet1.requestBill(10000.TGN);
    assert(wallet1.account.requested.length == 3);
    assert(wallet1.account.bills.length == 0);
    wallet1.account.add_bill(bill1);
    wallet1.account.add_bill(bill2);
    wallet1.account.add_bill(bill3);
    assert(wallet1.account.bills.length == 3);

    const to_pay = [TagionBill(19949.TGN, sdt_t.init, Pubkey([1, 2, 3, 4]), Buffer.init)];
    const to_pay2 = [TagionBill(30000.TGN, sdt_t.init, Pubkey([1, 2, 3, 4]), Buffer.init)];

    TagionCurrency fees;
    const res = wallet1.getFee(to_pay, fees, true);
    check(res.value == true, format("Wallet should be able to pay Amount: %s", res.msg));
    const res2 = wallet1.getFee(to_pay2, fees, true);
    check(res2.value == false, format("Wallet should not be able to pay Amount"));

    SignedContract signed_contract;
    const can_pay = wallet1.createPayment(to_pay, signed_contract, fees, true);
    check(can_pay.value == true, format("got error: %s", res.msg));
}

//get fee from amount
unittest {
    import tagion.script.execute;

    auto wallet1 = StdSecureWallet("some words", "1234");
    const bill1 = wallet1.requestBill(1400.TGN);
    const to_pay = wallet1.requestBill(500.TGN);
    wallet1.account.add_bill(bill1);

    TagionCurrency fee_amount;
    TagionCurrency fee_bill_amount;

    const res = wallet1.getFee(500.TGN, fee_amount);
    const res1 = wallet1.getFee([to_pay], fee_bill_amount);
    assert(res.value);
    assert(res1.value);
    assert(fee_amount == fee_bill_amount, format("not the same bill_fee=%s, amount_fee=%s", fee_bill_amount, fee_amount));
    // create the payment 
    SignedContract contract;
    TagionCurrency actual_fee;

    const payment = wallet1.createPayment([to_pay], contract, actual_fee);
    assert(payment.value);

    // const pay_script = PayScript(contract.contract.script);
    const calc_fees = ContractExecution.billFees(
            [bill1.toDoc],
            [to_pay.toDoc],
            wallet1.snavs_byte_fee,
    );
    assert(actual_fee == calc_fees, format("fees not the same actualFee=%s, calculatedFee=%s", actual_fee, calc_fees));

    assert(fee_amount == actual_fee, format("fees not the same getFee=%s, actualFee=%s", fee_amount, actual_fee));
}
