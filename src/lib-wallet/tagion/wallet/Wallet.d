module tagion.wallet.Wallet;

import tagion.crypto.SecureInterfaceNet : SecureNet;
import tagion.wallet.WalletRecords : DevicePIN, RecoverGenerator;
import tagion.wallet.AccountDetails;
import tagion.crypto.random.random;
import std.string : representation;
import tagion.wallet.Basic : saltHash;
import tagion.crypto.Types : Pubkey;
import tagion.basic.Types : Buffer;
import tagion.script.TagionCurrency;
import tagion.script.common;
import tagion.utils.StdTime;
import tagion.dart.DARTBasic;
import tagion.communication.HiRPC;
import tagion.hibon.Document;
import tagion.hibon.HiBON;
import tagion.Keywords;


import std.algorithm;
import std.format;
import std.array;
import std.range;


import tagion.wallet.WalletException : WalletException;
import tagion.basic.tagionexceptions : Check;
alias check = Check!(WalletException);


@safe
static TagionBill requestBill(TagionCurrency amount, Pubkey bill_owner, sdt_t bill_time = currentTime) {
    check(amount > 0.TGN, format("Requested bill should have a positive value and not %10.6fTGN", amount
            .value));
    TagionBill bill;
    bill.value = amount;
    bill.time = bill_time;
    auto nonce = new ubyte[4];
    getRandom(nonce);
    bill.nonce = nonce.idup;
    bill.owner = bill_owner;
    return bill;
}

@safe
struct Wallet(Net : SecureNet) {
    RecoverGenerator _wallet; /// Information to recover the seed-generator
    DevicePIN _pin; /// Information to check the Pin code

    AccountDetails account; /// Account-details holding the bills and generator

    protected SecureNet _net;
    enum long snavs_byte_fee = 100;

    @safe
    void createWallet(scope const(char[]) passphrase, scope const(char[]) pincode, scope const(char[]) salt = null) {

        void set_pincode(
            scope const(ubyte[]) R,
            scope const(char[]) pincode) scope
        in (_net !is null)
        do {
            auto seed = new ubyte[_net.hashSize];
            getRandom(seed);
            _pin.setPin(_net, R, pincode.representation, seed.idup);
        }

        scope(success) {
            // derive the first pubkey so that the root is never used
            deriveNewPubkey;
        }

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

    @safe
    void readWallet(DevicePIN pin, RecoverGenerator wallet, AccountDetails account) {
        _wallet = wallet;
        _pin = pin;
        this.account = account;
    }

    @safe
    bool login(const(char[]) pincode) {
        if (_pin.D) {
            _net = null;
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
     * Collects the bills for the amount
     * Params:
     *   amount = the amount to be collected
     *   locked_bills = the list of bills
     * Returns: true if wallet has enough to pay the amount
     */
    private bool collect_bills(const TagionCurrency amount, out TagionBill[] locked_bills) {
        import std.range : takeOne, tee;

        account.bills.sort!q{a.value > b.value};

        // Select all bills not in use
        auto none_locked = account.bills.filter!(
            b => !(_net.dartIndex(b) in account.activated)).array;

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
    TagionCurrency getFee(TagionCurrency amount, bool print = false) {
        import tagion.script.Currency : totalAmount;
        import tagion.script.execute;

        static immutable dummy_pubkey = Pubkey(new ubyte[33]);
        static immutable dummy_nonce = new ubyte[4];

        auto bill = TagionBill(amount, currentTime, dummy_pubkey, dummy_nonce);

        PayScript pay_script;
        pay_script.outputs = [bill];
        TagionBill[] collected_bills;
        TagionCurrency amount_remainder = 0.TGN;
        size_t previous_bill_count = size_t.max;
        TagionCurrency fees;

        const amount_to_pay = pay_script.outputs
            .map!(bill => bill.value)
            .totalAmount;
        const available_wallet_amount = account.available();

        do {
            collected_bills.length = 0;

            const amount_to_collect = amount_to_pay + (-1 * (amount_remainder)) + fees;
            check(amount_to_collect < available_wallet_amount, "Amount is too big with fees");
            const can_pay = collect_bills(amount_to_collect, collected_bills);
            check((collected_bills.length != previous_bill_count) || !can_pay, format("Is unable to pay the amount %10.6fTGN available %10.6fTGN", amount_to_pay.value, account.available()
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
        return fees;
    }

    private const(SecureNet[]) collectNets(const(TagionBill[]) bills) {
        return bills
            .map!(bill => bill.owner in account.derivers)
            .map!((deriver) => (deriver is null) ? _net.init : _net.derive(*deriver))
            .array;
    }
    
    void lock_bills(const(TagionBill[]) locked_bills) {
        locked_bills.each!(b => account.activated[_net.dartIndex(b)] = true);
    }
    SignedContract createPayment(const(TagionBill)[] to_pay, out TagionCurrency fees, bool print = false) {
        import tagion.hibon.HiBONtoText;
        import tagion.script.Currency : totalAmount;
        import tagion.script.execute;

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
            check(collected_bills.length != previous_bill_count, "unable to pay");
            check(collected_bills.length != 0, "unable to pay");
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
            auto bill_remain = requestBill(amount_remainder, getCurrentPubkey);
            auto derive = _net.HMAC(bill_remain.toDoc.serialize);
            account.requestBill(bill_remain, derive);
            pay_script.outputs ~= bill_remain;
        }
        lock_bills(collected_bills);
        check(nets.length == collected_bills.length, format("number of bills does not match number of signatures nets %s, collected_bills %s", nets
                .length, collected_bills.length));

        return sign(
            nets,
            collected_bills.map!(bill => bill.toDoc)
                .array,
                null,
                pay_script.toDoc);
    }

    /** 
     * Returns: Current pubkey 
     */
    Pubkey getCurrentPubkey() {
        return _net.derivePubkey(account.derive_state);
    }

    /** 
     * Derives a new pubkey
     * Requires saving afterwards
     */
    void deriveNewPubkey() {
        account.derive_state = _net.HMAC(account.derive_state ~ _net.pubkey);

        auto pkey = _net.derivePubkey(account.derive_state);
        account.derivers[pkey] = account.derive_state;
    }

    /**
     * Calculates the amount which can be activate
     * Returns: the amount of available amount
     */
    TagionCurrency available_balance() const {
        return account.available;
    }

    /**
     * Calcutales the locked amount in the network
     * Returns: the locked amount
     */
    TagionCurrency locked_balance() const {
        return account.locked;
    }

    /**
     * Calcutales the total amount
     * Returns: total amount
     */
    TagionCurrency total_balance() const {
        return account.total;
    }
    /** 
     * Used for first step in updating wallet from TRT.
     * Creates a trt.dartRead command for the TRT.
     * Takes all derivers in the wallet and convert the pubkeys to #pubkey for lookup in TRT
     * These indices are put into the trt.dartRead specifying the command.
     * Params:
     *   hirpc = hirpc to use
     * Returns: trt.dartRead hirpc.sender 
     */
    const(HiRPC.Sender) readIndicesByPubkey(HiRPC hirpc = HiRPC(null)) const {
        import tagion.dart.DART;
        import tagion.script.standardnames;

        auto owner_indices = account.derivers.byKey
            .map!(owner => _net.dartKey(TRTLabel, owner));

        auto params = new HiBON;
        auto params_dart_indices = new HiBON;
        params_dart_indices = owner_indices;
        params[DART.Params.dart_indices] = params_dart_indices;
        return hirpc.action("trt." ~ DART.Queries.dartRead, params);
    }

    /** 
     * Used for reading contract from TRT.
     * Creates a trt.dartRead command for the TRT.
     * Takes hash of given contract and creates dart index with #contract for lookup in TRT
     * These indices are put into the trt.dartRead specifying the command.
     * Params:
     *   contracts = list of contracts to lookup
     *   hirpc = hirpc to use
     * Returns: trt.dartRead hirpc.sender
     */
    const(HiRPC.Sender) readContractsTRT(const(Document)[] contracts, HiRPC hirpc = HiRPC(null)) const {
        import tagion.dart.DART;
        import tagion.script.standardnames;

        DARTIndex[] contract_indices = contracts.map!(doc => _net.dartIndex(doc))
            .map!(idx => _net.dartKey(StdNames.contract, idx))
            .array;

        auto params = new HiBON;
        auto params_dart_indices = new HiBON;
        params_dart_indices = contract_indices;
        params[DART.Params.dart_indices] = params_dart_indices;
        return hirpc.action("trt." ~ DART.Queries.dartRead, params);
    }

    /** 
     * Second stage in updating wallet.
     * Takes a read trt.dartRead recorder.
     * Creates an array of DARTindices from readIndicesByPubkey recorder
     * If some indices were found in the wallet but not in the trt, the indices are removed
        from the wallet.
     * If some indices were found in the trt but not in the wallet, the indices are put
        into a new dartRead request.
     * Params:
     *   receiver = Received response from trt.dartRead
     * Returns: HiRPC.Sender.init if it is not needed to perform 
        additional requests on the DART.
     */
    const(HiRPC.Sender) differenceInIndices(const(HiRPC.Receiver) receiver) {
        import tagion.dart.Recorder;
        import tagion.hibon.HiBONRecord : isRecord;
        import tagion.trt.TRT : TRTArchive;
        import tagion.dart.DARTcrud;

        if (!receiver.isResponse) {
            return HiRPC.Sender.init;
        }

        const recorder_doc = receiver.message[Keywords.result].get!Document;
        // writefln("recorder \n %s", recorder_doc.toPretty);
        RecordFactory record_factory = RecordFactory(_net);
        // TODO: catch hibon exception;
        const recorder = record_factory.recorder(recorder_doc);
        /// list of dart_indices in response
        auto dart_indices = recorder[]
            .map!(a => a.filed)
            .filter!(doc => doc.isRecord!TRTArchive)
            .map!(doc => TRTArchive(doc))
            .filter!(a => !a.indices.empty)
            .map!(trt_archive => trt_archive.indices)
            .join
            .sort!((a, b) => a < b);

        auto bill_indices = account.bills
            .map!(b => DARTIndex(_net.dartIndex(b)));

        auto locked_indices = account.activated
            .byKey;

        auto to_compare = chain(bill_indices, locked_indices)
            .array
            .sort!((a, b) => a < b)
            .uniq; // remove duplicates

        DARTIndex[] to_be_looked_up_indices; /// indices that were in network but not in wallet
        DARTIndex[] to_be_removed_from_wallet; /// indices that were removed from network but not in our wallet

        /*
        * If to_be_lookup_up_indices is empty that means no new archives were added 
        to the database otherwise there are new archives we must lookup. 
        * If to_be_removed_from_wallet is empty none of our own bills were removed 
        from the database. 
        * Though if it is not empty we know that the archive must have been deleted 
        from the database and should be removed from our wallet.
        */
        foreach (d; dart_indices) {
            if (!to_compare.canFind(d)) {
                to_be_looked_up_indices ~= d;
            }
        }
        foreach (d; to_compare) {
            if (!dart_indices.canFind(d)) {
                to_be_removed_from_wallet ~= d;
            }
        }

        DARTIndex[] network_indices; /// indices for network lookup

        /// check to_be_looked_up_indices for matches in requested.
        foreach (i, d; to_be_looked_up_indices) {
            if (d in account.requested) {
                auto new_bill = account.requested[d];
                if (!account.bills.canFind(new_bill)) {
                    account.bills ~= new_bill;
                    account.requested.remove(d);
                }
            }
            else {
                network_indices ~= d;
            }
        }

        foreach (idx; to_be_removed_from_wallet) {
            account.activated.remove(idx);
            account.remove_bill_by_hash(idx);
        }

        const new_req = network_indices.empty ? HiRPC.Sender.init : dartRead(network_indices);
        return new_req;
    }

    /** 
     * Updates the wallet based on the received dartRead
     * Params:
     *   receiver = received dartRead from DART
     * Returns: true if the update was successful and false if not.
     */
    bool updateFromRead(const(HiRPC.Receiver) receiver) {
        import tagion.dart.Recorder;
        import tagion.hibon.HiBONRecord : isRecord;

        if (!receiver.isResponse) {
            return false;
        }
        const recorder_doc = receiver.message[Keywords.result].get!Document;
        RecordFactory record_factory = RecordFactory(_net);
        const recorder = record_factory.recorder(recorder_doc);
        auto new_bills = recorder[]
            .map!(a => a.filed)
            .filter!(doc => doc.isRecord!TagionBill)
            .map!(doc => const(TagionBill)(doc));

        foreach (new_bill; new_bills) {
            if (!account.bills.canFind(new_bill)) {
                account.bills ~= new_bill;
            }
            account.remove_requested_by_hash(_net.dartIndex(new_bill));
            account.remove_invoice_by_pkey(new_bill.owner);
        }
        return true;
    }

    version(unittest) {
        TagionBill addBill(TagionCurrency amount) {
            auto bill_to_add = requestBill(amount, getCurrentPubkey);
            account.bills ~= bill_to_add;
            account.remove_requested_by_hash(_net.dartIndex(bill_to_add));
            account.remove_invoice_by_pkey(bill_to_add.owner);
            return bill_to_add;
        }
    }
}


version(unittest) {
    import tagion.crypto.SecureNet;
    alias SimpleWallet = Wallet!StdSecureNet;
}


/// check pubkey derivation
unittest {

    SimpleWallet wallet1;
    wallet1.createWallet("wowo wowo", "1234");

    const current_pkey = wallet1.getCurrentPubkey;
    wallet1.deriveNewPubkey;
    const new_pkey = wallet1.getCurrentPubkey;
    const same_pkey = wallet1.getCurrentPubkey;

    assert(current_pkey != new_pkey, "did not derive new pkey");
    assert(new_pkey == same_pkey, "should be the same on call without derivation");

    /// open the same wallet login and check keys
    SimpleWallet wallet_copy;
    wallet_copy.readWallet(wallet1._pin, wallet1._wallet, wallet1.account);
    wallet_copy.login("1234");

    assert(new_pkey == wallet_copy.getCurrentPubkey, "Should be the same after new login");
}

/// add some bills
unittest {
    // /// create a wallet
    SimpleWallet wallet1;
    SimpleWallet wallet2;

    wallet1.createWallet("wowo wowo", "1234");
    wallet2.createWallet("wowo loko", "2234");

    auto bill = wallet1.addBill(1000.TGN);

    // wallet 1 pays to wallet2 pkey;
    auto bill_to_pay = requestBill(500.TGN, wallet2.getCurrentPubkey);

    TagionCurrency fees;
    const signed_contract = wallet1.createPayment([bill_to_pay], fees);


}
