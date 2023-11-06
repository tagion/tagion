module tagion.mobile.WalletWrapperSdk;

import tagion.mobile.DocumentWrapperApi;

// import tagion.mobile.WalletStorage;
import tagion.hibon.Document;
import core.runtime : rt_init, rt_term;
import core.stdc.stdlib;
import std.stdint;
import std.string : toStringz, fromStringz;
import std.array;
import std.random;

//import std.stdio;
import std.path;
import std.range;
import std.algorithm;
import std.file : exists, remove;
import core.stdc.string;
import std.string : splitLines;

import Wallet = tagion.wallet.SecureWallet;
import tagion.script.TagionCurrency;
import tagion.script.common;
import tagion.wallet.AccountDetails;
import tagion.communication.HiRPC;
import tagion.hibon.HiBON;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord : HiBONRecord;
import tagion.hibon.HiBONFile : fwrite, fread;
import tagion.basic.Types : Buffer, FileExtension;
import tagion.crypto.Types : Pubkey;
import tagion.crypto.aes.AESCrypto;
import tagion.crypto.SecureNet : StdSecureNet, BadSecureNet;
import tagion.crypto.SecureNet;
import tagion.wallet.KeyRecover;
import tagion.wallet.WalletRecords : RecoverGenerator, DevicePIN;
import tagion.crypto.Cipher;
import tagion.utils.StdTime;
import tagion.wallet.WalletException;

enum TAGION_HASH = import("revision.mixin").splitLines[2];

/// Used for describing the d-runtime status
enum DrtStatus {
    DEFAULT_STS,
    STARTED,
    TERMINATED
}
/// Variable, which repsresents the d-runtime status
__gshared DrtStatus __runtimeStatus = DrtStatus.DEFAULT_STS;
// Wallet global variable.
alias StdSecureWallet = Wallet.SecureWallet!(StdSecureNet);

//static __wallet_storage.wallet = StdSecureWallet(DevicePIN.init);

// Storage global variable.
static WalletStorage* __wallet_storage;

static StdSecureWallet[string] wallets;
static Exception last_error;
/// Functions called from d-lang through dart:ffi
extern (C) {

    // Staritng d-runtime
    export static int64_t start_rt() {
        if (__runtimeStatus is DrtStatus.DEFAULT_STS) {
            __runtimeStatus = DrtStatus.STARTED;
            return rt_init;
        }
        return -1;
    }

    // Terminating d-runtime
    export static int64_t stop_rt() {
        if (__runtimeStatus is DrtStatus.STARTED) {
            __runtimeStatus = DrtStatus.TERMINATED;
            return rt_term;
        }
        return -1;
    }

    // Storage should be initialised once with correct file path
    // before using other wallet's functionality.
    export uint wallet_storage_init(const char* pathPtr, uint32_t pathLen) {
        const directoryPath = cast(char[])(pathPtr[0 .. pathLen]);
        if (directoryPath.length > 0) {
            // Full path to stored wallet data.
            const walletDataPath = directoryPath;
            __wallet_storage = new WalletStorage(walletDataPath);
            return 1;
        }

        return 0;
    }

    // Check if wallet was already created.
    export uint wallet_check_exist() {
        return __wallet_storage.isWalletExist();
    }

    version (none) export uint wallet_create(
            const uint8_t* pincodePtr,
            const uint32_t pincodeLen,
            const uint16_t* mnemonicPtr,
            const uint32_t mnemonicLen) {
        // Restore data from pointers.  
        auto pincode = cast(char[])(pincodePtr[0 .. pincodeLen]);
        auto mnemonic = mnemonicPtr[0 .. mnemonicLen];
        scope (exit) {
            scramble(pincode);
        }
        // Create a wallet from inputs.
        __wallet_storage.wallet = StdSecureWallet(
                mnemonic,
                pincode
        );

        return __wallet_storage.write;

    }

    export uint wallet_create(
            const uint8_t* pincodePtr,
            const uint32_t pincodeLen,
            const uint8_t* mnemonicPtr,
            const uint32_t mnemonicLen,
            const uint8_t* saltPtr,
            const uint32_t saltLen) nothrow {
        try {
            auto pincode = cast(char[])(pincodePtr[0 .. pincodeLen]);
            auto mnemonic = cast(char[]) mnemonicPtr[0 .. mnemonicLen];

            check(saltPtr is null && saltLen is 0 || saltPtr !is null, "Casting went wrong");

            auto salt = cast(char[]) saltPtr[0 .. saltLen];
            scope (exit) {
                scramble(pincode);
                scramble(mnemonic);
                scramble(salt);
            }
            // Create a wallet from inputs.
            __wallet_storage.wallet = StdSecureWallet(
                    mnemonic,
                    pincode,
                    salt
            );
            __wallet_storage.write;
        }
        catch (Exception e) {
            last_error = e;
            return 0;
        }
        return 1;
    }

    export uint wallet_login(const uint8_t* pincodePtr, const uint32_t pincodeLen) nothrow {

        // Restore data from ponters.
        try {
            auto pincode = cast(char[])(pincodePtr[0 .. pincodeLen]);
            scope (exit) {
                scramble(pincode);
            }
            __wallet_storage.read;
            return __wallet_storage.wallet.login(pincode);
        }
        catch (Exception e) {
            last_error = e;
        }
        return 0;
    }

    export uint wallet_logout() nothrow {
        if (__wallet_storage.wallet.isLoggedin()) {
            __wallet_storage.wallet.logout();
            // Set wallet to default.
            __wallet_storage.wallet = __wallet_storage.wallet.init;
            return 1;
        }
        return 0;
    }

    export uint wallet_check_login() {
        return __wallet_storage.wallet.isLoggedin();
    }

    export uint wallet_delete() {
        // Try to remove wallet file.
        if (__wallet_storage !is null && __wallet_storage.remove()) {
            __wallet_storage.wallet.logout();
            // Set wallet to default.
            //defaultWallet();
            __wallet_storage.wallet = __wallet_storage.wallet.init;
            return 1;
        }
        return 0;
    }

    export uint validate_pin(const uint8_t* pincodePtr, const uint32_t pincodeLen) {
        // Restore data from ponters.
        const pincode = cast(char[])(pincodePtr[0 .. pincodeLen]);

        if (__wallet_storage.wallet.isLoggedin()) {
            return __wallet_storage.wallet.checkPincode(pincode);
        }
        return 0;
    }

    // TODO: Get info if it's possible to change a pincode without providing a current one.
    export uint change_pin(
            const uint8_t* pincodePtr,
            const uint32_t pincodeLen,
            const uint8_t* newPincodePtr,
            const uint32_t newPincodeLen) {
        const pincode = cast(char[])(pincodePtr[0 .. pincodeLen]);
        const newPincode = cast(char[])(newPincodePtr[0 .. newPincodeLen]);

        if (__wallet_storage.wallet.isLoggedin()) {
            if (__wallet_storage.wallet.changePincode(pincode, newPincode)) {
                __wallet_storage.write;
                // Since secure_wallet do logout after pincode change
                // we need to perform a login manualy.
                __wallet_storage.wallet.login(newPincode);
                return 1;
            }
        }
        return 0;
    }

    export uint get_fee(const double amount, double* fees) {
        TagionCurrency tgn_fees;
        scope (exit) {
            *fees = tgn_fees.value;
        }

        const can_pay = __wallet_storage.wallet.getFee(TagionCurrency(amount), tgn_fees);
        return can_pay.value ? 1 : 0;
    }

    export uint create_nft_contract(
            uint32_t* signedContractPtr,
            uint8_t* nftPtr,
            const uint32_t nftLen) {

        immutable nftBuff = cast(immutable)(nftPtr[0 .. nftLen]);

        if (__wallet_storage.wallet.isLoggedin()) {
            auto nft = Document(nftBuff);

            SignedContract signed_contract;

            const is_created = __wallet_storage.wallet.createNFT(nft, signed_contract);
            if (is_created) {
                const nftDocId = recyclerDoc.create(signed_contract.toDoc);
                // Save wallet state to file.
                __wallet_storage.write;

                *signedContractPtr = nftDocId;
                return 1;
            }
        }
        return 0;
    }

    export uint create_contract(
            uint32_t* contractPtr,
            const uint8_t* invoicePtr,
            const uint32_t invoiceLen,
            const double amount,
            double* fees) {

        immutable invoiceBuff = cast(immutable)(invoicePtr[0 .. invoiceLen]);
        TagionCurrency tgn_fees;
        scope (exit) {
            *fees = tgn_fees.value;

        }

        if (__wallet_storage.wallet.isLoggedin()) {
            auto invoice = Invoice(Document(invoiceBuff));
            invoice.amount = TagionCurrency(amount);

            SignedContract signed_contract;
            const can_pay =
                __wallet_storage.wallet.payment([invoice], signed_contract, tgn_fees);
            if (can_pay) {
                /*
                HiRPC hirpc;
                const sender = hirpc.action("transaction", signed_contract.toHiBON);
                const contractDocId = recyclerDoc.create(Document(sender.toHiBON));
*/
                const contractDocId = recyclerDoc.create(signed_contract.toDoc);
                // Save wallet state to file.
                __wallet_storage.write;

                *contractPtr = contractDocId;
                return 1;
            }
        }
        return 0;
    }

    export uint create_invoice(
            uint8_t* invoicePtr,
            const double amount,
            const char* labelPtr,
            const uint32_t labelLen) {

        immutable label = cast(immutable)(labelPtr[0 .. labelLen]);

        if (__wallet_storage.wallet.isLoggedin()) {
            auto invoice = StdSecureWallet.createInvoice(
                    label, amount.TGN);
            __wallet_storage.wallet.registerInvoice(invoice);

            const invoiceDocId = recyclerDoc.create(invoice.toDoc);
            // Save wallet state to file.
            __wallet_storage.write;

            *invoicePtr = cast(uint8_t) invoiceDocId;
            return 1;
        }
        return 0;
    }

    export uint request_update(uint8_t* requestPtr) {

        if (__wallet_storage.wallet.isLoggedin()) {
            const request = __wallet_storage.wallet.getRequestUpdateWallet();
            const requestDocId = recyclerDoc.create(request.toDoc);
            *requestPtr = cast(uint8_t) requestDocId;
            return 1;
        }
        return 0;

    }

    export uint update_response(uint8_t* responsePtr, uint32_t responseLen) {
        import tagion.hibon.HiBONException;

        immutable response = cast(immutable)(responsePtr[0 .. responseLen]);

        if (__wallet_storage.wallet.isLoggedin()) {

            HiRPC hirpc;

            try {
                auto receiver = hirpc.receive(Document(response));
                const result = __wallet_storage.wallet.setResponseUpdateWallet(receiver);

                if (result) {
                    // Save wallet state to file.
                    __wallet_storage.write;
                    return 1;
                }
            }
            catch (HiBONException e) {
                return 0;
            }
        }

        return 0;
    }

    // export void toPretty(uint8_t* docPtr, uint32_t responseLen, char* resultPtr, uint32_t* resultLen) {
    export void toPretty(uint8_t* docPtr, uint32_t responseLen, uint8_t* resultPtr) {
        immutable res = cast(immutable)(docPtr[0 .. responseLen]);
        Document doc = Document(res);

        import tagion.hibon.HiBONJSON : toPretty;

        string docToPretty = doc.toPretty;

        auto result = new HiBON();
        result["pretty"] = docToPretty;

        const resultDocId = recyclerDoc.create(Document(result));
        *resultPtr = cast(uint8_t) resultDocId;
        // resultPtr = cast(char*) &result[0];
        // *resultLen = cast(uint32_t) result.length;
    }

    @safe
    export double get_locked_balance() {
        const balance = __wallet_storage.wallet.locked_balance();
        return balance.value;
    }

    @safe
    export double get_balance() {
        const balance = __wallet_storage.wallet.available_balance();
        return balance.value;
    }

    export uint get_public_key(uint8_t* pubkeyPtr) {
        if (__wallet_storage.wallet.isLoggedin()) {
            const pubkey = __wallet_storage.wallet.getPublicKey();

            auto result = new HiBON();
            result["pubkey"] = pubkey;

            const pubkeyDocId = recyclerDoc.create(Document(result));

            *pubkeyPtr = cast(uint8_t) pubkeyDocId;

            return 1;
        }
        return 0;
    }

    export uint get_derivers_state(uint8_t* deriversStatePtr) {
        if (__wallet_storage.wallet.isLoggedin()) {
            const deriversState = __wallet_storage.wallet.getDeriversState();

            auto result = new HiBON();
            result["derivers_state"] = deriversState;

            const deviversStateDocId = recyclerDoc.create(Document(result));

            *deriversStatePtr = cast(uint8_t) deviversStateDocId;

            return 1;
        }
        return 0;
    }

    version (none) export uint get_derivers(uint8_t* deriversPtr) {
        if (__wallet_storage.wallet.isLoggedin()) {
            const encrDerivers = __wallet_storage.wallet.getEncrDerivers();
            const deviversDocId = recyclerDoc.create(Document(encrDerivers.toHiBON));

            *deriversPtr = cast(uint8_t) deviversDocId;

            return 1;
        }
        return 0;
    }

    version (none) export uint set_derivers(const uint8_t* deriversPtr, const uint32_t deriversLen) {

        immutable encDerivers = cast(immutable)(deriversPtr[0 .. deriversLen]);

        if (__wallet_storage.wallet.isLoggedin()) {
            __wallet_storage.wallet.setEncrDerivers(Cipher.CipherDocument(Document(encDerivers)));
            return 1;
        }
        return 0;
    }

    export uint get_backup(uint8_t* backupPtr) {
        if (__wallet_storage.wallet.isLoggedin()) {
            const encrAccount = __wallet_storage.wallet.getEncrAccount();
            const backupDocId = recyclerDoc.create(encrAccount.toDoc);

            *backupPtr = cast(uint8_t) backupDocId;

            return 1;
        }
        return 0;
    }

    export uint set_backup(const uint8_t* backupPtr, const uint32_t backupLen) {

        immutable account = cast(immutable)(backupPtr[0 .. backupLen]);

        if (__wallet_storage.wallet.isLoggedin()) {
            __wallet_storage.wallet.setEncrAccount(Cipher.CipherDocument(Document(account)));
            __wallet_storage.write;
            return 1;
        }
        return 0;
    }

    export uint add_bill(const uint8_t* billPtr, const uint32_t billLen) {

        immutable billBuffer = cast(immutable)(billPtr[0 .. billLen]);

        if (__wallet_storage.wallet.isLoggedin()) {
            auto bill = TagionBill(Document(billBuffer));
            __wallet_storage.wallet.account.add_bill(bill);
            return 1;
        }
        return 0;
    }

    export uint remove_bill(uint8_t* pubKeyPtr, uint32_t pubKeyLen) {
        immutable(ubyte)[] pubKey = cast(immutable(ubyte)[])(pubKeyPtr[0 .. pubKeyLen]);

        if (__wallet_storage.wallet.isLoggedin()) {
            const result = __wallet_storage.wallet.account.remove_bill(Pubkey(pubKey));
            return result;
        }
        return 0;
    }

    export uint remove_bills_by_contract(const uint8_t* contractPtr, const uint32_t contractLen) {
        // Collect input and output keys from the contract.
        // Iterate them and call remove on each.

        immutable contractBuffer = cast(immutable)(contractPtr[0 .. contractLen]);

        if (__wallet_storage.wallet.isLoggedin()) {

            auto contractDoc = Document(contractBuffer);

            // Contract inputs.
            const messageTag = "$msg";
            const paramsTag = "params";

            auto messageDoc = contractDoc[messageTag].get!Document;
            auto paramsDoc = messageDoc[paramsTag].get!Document;
            auto sContract = SignedContract(paramsDoc);

            import std.algorithm;

            sContract.contract.inputs.each!(hash => __wallet_storage.wallet.account.remove_bill_by_hash(hash));

            return 1;
        }
        return 0;
    }

    export uint ulock_bills_by_contract(const uint8_t* contractPtr, const uint32_t contractLen) {

        immutable contractBuffer = cast(immutable)(contractPtr[0 .. contractLen]);

        if (__wallet_storage.wallet.isLoggedin()) {

            auto contractDoc = Document(contractBuffer);

            // Contract inputs.
            const messageTag = "$msg";
            const paramsTag = "params";

            auto messageDoc = contractDoc[messageTag].get!Document;
            auto paramsDoc = messageDoc[paramsTag].get!Document;
            auto sContract = SignedContract(paramsDoc);

            import std.algorithm;

            sContract.contract.inputs.each!(hash => __wallet_storage.wallet.account.unlock_bill_by_hash(hash));

            return 1;
        }
        return 0;
    }

    export uint check_contract_payment(const uint8_t* contractPtr, const uint32_t contractLen, uint8_t* statusPtr) {
        immutable contractBuffer = cast(immutable)(contractPtr[0 .. contractLen]);

        if (__wallet_storage.wallet.isLoggedin()) {

            auto contractDoc = Document(contractBuffer);

            // Contract inputs.
            const messageTag = "$msg";
            const paramsTag = "params";

            auto messageDoc = contractDoc[messageTag].get!Document;
            auto paramsDoc = messageDoc[paramsTag].get!Document;
            auto sContract = SignedContract(paramsDoc);
            const outputs = PayScript(sContract.contract.script).outputs.map!(output => output.toDoc).array;

            int status = __wallet_storage.wallet.account.check_contract_payment(
                    sContract.contract.inputs, outputs);

            *statusPtr = cast(uint8_t) status;
            return 1;
        }
        return 0;
    }

    export uint check_invoice_payment(const uint8_t* invoicePtr, const uint32_t invoiceLen, double* amountPtr) {
        immutable invoiceBuffer = cast(immutable)(invoicePtr[0 .. invoiceLen]);

        if (__wallet_storage.wallet.isLoggedin()) {

            auto amount = TagionCurrency(0);
            auto invoice = Invoice(Document(invoiceBuffer));
            auto isExist = __wallet_storage.wallet.account.check_invoice_payment(invoice.pkey, amount);

            if (isExist) {
                *amountPtr = amount.value;
                return 1;
            }
        }
        return 0;
    }
}

unittest {
    const work_path = new_test_path;
    scope (success) {
        work_path.rmdirRecurse;
    }
    { // Init storage should fail with empty path.
        __wallet_storage = null;
        const char[] path;
        const pathLen = cast(uint32_t) path.length;
        const result = wallet_storage_init(path.ptr, pathLen);
        // Check the result
        assert(result == 0);
        assert(__wallet_storage is null);
    }

    { // Init storage with correct path.
        const path = work_path;
        const uint32_t pathLen = cast(uint32_t) path.length;
        const uint result = wallet_storage_init(path.ptr, pathLen);
        // Check the result
        assert(result != 0, "Expected non-zero result");
        assert(__wallet_storage !is null);
    }

    { // Wallet create.
        // Create input data
        const uint8_t[] pincode = cast(uint8_t[]) "1234".dup;
        const uint32_t pincodeLen = cast(uint32_t) pincode.length;
        const uint8_t[] mnemonic = cast(uint8_t[]) "some words".dup;
        const uint32_t mnemonicLen = cast(uint32_t) mnemonic.length;
        const uint8_t[] salt = cast(uint8_t[]) "salt".dup;
        const uint32_t saltLen = cast(uint32_t) salt.length;

        // Call the wallet_create function
        const uint result = wallet_create(pincode.ptr, pincodeLen, mnemonic.ptr, mnemonicLen, salt.ptr, saltLen);

        // Check the result
        assert(result != 0, "Expected non-zero result");
    }

    { // Check if wallet was created.
        const uint result = wallet_check_exist();
        // Check the result
        assert(result != 0, "Expected non-zero result");
    }

    { // Fail to login to a wallet with an incorrect pincode.
        const uint8_t[] pincode = cast(uint8_t[]) "5555".dup;
        const uint32_t pincodeLen = cast(uint32_t) pincode.length;
        const uint result = wallet_login(pincode.ptr, pincodeLen);
        // Check the result
        assert(result == 0);
    }

    { // Login to wallet with a correct pincode.
        const uint8_t[] pincode = cast(uint8_t[]) "1234".dup;
        const uint32_t pincodeLen = cast(uint32_t) pincode.length;
        const uint result = wallet_login(pincode.ptr, pincodeLen);
        // Check the result
        assert(result != 0, "Expected non-zero result");
    }

    { // Check login
        const uint result = wallet_check_login();
        // Check the result
        assert(result != 0, "Expected non-zero result");
    }

    { // Logout wallet.
        const result = wallet_logout();
        assert(result != 0, "Expected non-zero result");
        assert(!__wallet_storage.wallet.isLoggedin);
    }

    { // Delete wallet.

        const result = wallet_delete();
        assert(result != 0, "Expected non-zero result");
        assert(!__wallet_storage.wallet.isLoggedin);
        assert(!__wallet_storage.isWalletExist);
    }

    { // Validate pin.

        const uint8_t[] pincode = cast(uint8_t[]) "1234".dup;
        const uint32_t pincodeLen = cast(uint32_t) pincode.length;
        const uint8_t[] mnemonic = cast(uint8_t[]) "some words".dup;
        const uint32_t mnemonicLen = cast(uint32_t) mnemonic.length;
        uint8_t[] pin_copy;
        // Call the wallet_create function
        pin_copy = pincode.dup;
        wallet_create(pin_copy.ptr, pincodeLen, mnemonic.ptr, mnemonicLen, const(uint8_t*).init, uint32_t.init);
        pin_copy = pincode.dup;
        wallet_login(pin_copy.ptr, pincodeLen);

        const uint result = validate_pin(pincode.ptr, pincodeLen);
        assert(result != 0, "Expected non-zero result");
    }

    { // Validate pin should fail on incorrect pincode.
        const uint8_t[] pincode = cast(uint8_t[]) "5555".dup;
        const uint32_t pincodeLen = cast(uint32_t) pincode.length;
        const uint result = validate_pin(pincode.ptr, pincodeLen);
        assert(result == 0);
    }

    { // Change pincode.
        const uint8_t[] pincode = cast(uint8_t[]) "1234".dup;
        const uint32_t pincodeLen = cast(uint32_t) pincode.length;
        const uint8_t[] newPincode = cast(uint8_t[]) "5555".dup;
        const uint32_t newPincodeLen = cast(uint32_t) newPincode.length;
        const uint result = change_pin(pincode.ptr, pincodeLen, newPincode.ptr, newPincodeLen);
        assert(result != 0, "Expected non-zero result");
        assert(__wallet_storage.wallet.isLoggedin, "Expected wallet stays logged in");
    }
}

version (none) unittest {
    import tagion.hibon.HiBONtoText;

    const work_path = new_test_path;
    //__wallet_storage=new WalletStorage(work_path);
    scope (success) {
        work_path.rmdirRecurse;
    }

    // Create new test wallet
    {
        const result = wallet_storage_init(work_path.ptr, cast(uint32_t) work_path.length);
        assert(result == 1, "Wallet can not be intialized");
    }
    // Create input data
    const uint64_t invAmount = 100;
    const char[] label = "Test Invoice";
    const uint32_t labelLen = cast(uint32_t) label.length;
    uint8_t invoiceDocId;

    { // Create invoice.

        // Call the create_invoice function
        const uint result = create_invoice(&invoiceDocId, invAmount, label.ptr, labelLen);

        // Check the result
        assert(result == 1, "Expected result to be 1");

        // Verify that invoiceDocId is non-zero
        assert(invoiceDocId != 0, "Expected non-zero invoiceDocId");
    }

    import std.algorithm : map;
    import std.string : representation;
    import std.range : zip;

    auto bill_amounts = [200, 500, 100].map!(a => a.TGN);
    [200, 500, 100]
        .map!(value => value.TGN)
        .map!(value => __wallet_storage.wallet.requestBill(value))
        .each!(bill => __wallet_storage.wallet.addBill(bill));

    const net = new StdHashNet;
    //auto gene = cast(Buffer) net.calcHash("gene".representation);

    import tagion.utils.Miscellaneous : hex;

    // Add the bills to the account with the derive keys
    with (__wallet_storage.wallet.account) {

        bills = zip(bill_amounts, derivers.byKey)
            .map!(bill_derive => TagionBill(
                    bill_derive[0],
                    currentTime,
                    bill_derive[1],
                    Buffer.init)).array;
    }

    auto invoiceDoc = recyclerDoc(invoiceDocId);

    // Contract input data.
    const uint8_t[] invoice = cast(uint8_t[])(invoiceDoc.serialize);
    const uint32_t invoiceLen = cast(uint32_t) invoice.length;
    const uint64_t contAmount = 100;

    uint32_t contractDocId;

    { // Create a contract.
        double fees;
        const uint result = create_contract(&contractDocId, invoice.ptr, invoiceLen, contAmount, &fees);
        // Check the result
        assert(result == 1, "Expected result to be 1");

        // Verify that invoiceDocId is non-zero
        assert(contractDocId != 0, "Expected non-zero contractDocId");
    }

    version (none) {
        auto contractDoc = recyclerDoc(contractDocId);

        const uint8_t[] contract = cast(uint8_t[])(contractDoc.serialize);
        const uint32_t contractLen = cast(uint32_t) contract.length;

        { // Update request.
            uint8_t requestDocId;
            const uint result = request_update(&requestDocId);

            // Check the result
            assert(result == 1, "Expected result to be 1");

            // Verify that invoiceDocId is non-zero
            assert(requestDocId != 0, "Expected non-zero requestDocId");
        }
        { // Get public key.
            uint8_t pubkeyDocId;
            uint result = get_public_key(&pubkeyDocId);

            // Check the result
            assert(result == 1, "Expected result to be 1");

            // Verify that invoiceDocId is non-zero
            assert(pubkeyDocId != 0, "Expected non-zero pubkeyDocId");
        }

        { // Get and set derivers.
            uint8_t deriversDocId;
            uint getDResult = get_derivers(&deriversDocId);

            // Check the result
            assert(getDResult == 1, "Expected result to be 1");

            // Verify that invoiceDocId is non-zero
            assert(deriversDocId != 0, "Expected non-zero deriversDocId");

            auto deriversDoc = recyclerDoc(deriversDocId);

            // Derivers input data.
            const uint8_t[] derivers = cast(uint8_t[])(deriversDoc.serialize);
            const uint32_t deriversLen = cast(uint32_t) derivers.length;

            uint setDResult = set_derivers(derivers.ptr, deriversLen);

            // Check the result
            assert(setDResult == 1, "Expected result to be 1");
        }

        { // Get derivers state.
            uint8_t deriversDocId;
            uint getDResult = get_derivers_state(&deriversDocId);

            // Check the result
            assert(getDResult == 1, "Expected result to be 1");

            // Verify that invoiceDocId is non-zero
            assert(deriversDocId != 0, "Expected non-zero deriversDocId");
        }

        { // Add a new bill.
            import std.algorithm : map;
            import std.string : representation;
            import std.range : zip;

            import tagion.utils.Miscellaneous : hex;

            TagionBill[] newBills;

            // Add the bills to the account with the derive keys
            version (none) {
                with (__wallet_storage.wallet.account) {
                    newBills = zip(bill_amounts, derivers.byKey).map!(bill_derive => TagionBill(bill_derive[0],
                            epoch, bill_derive[1], gene)).array;
                }

                const uint8_t[] bill = cast(uint8_t[]) newBills[0].toHiBON.serialize;
                const uint32_t billLen = cast(uint32_t) bill.length;

                uint result = add_bill(bill.ptr, billLen);

                // Check the result
                assert(result == 1, "Expected result to be 1");
            }
        }
        { // Ulock bills by contract

            uint result = ulock_bills_by_contract(contract.ptr, contractLen);

            // Check the result
            assert(result == 1, "Expected result to be 1");
        }
        { // Check invoice payment

            double amount;
            auto result = check_invoice_payment(invoice.ptr, invoiceLen, &amount);

            // Check the result
            assert(result == 1, "Expected result to be 1");
            assert(amount != 0, "Expected amount not to be 0");
        }
        { // Check contract payment

            uint8_t status;

            uint result = check_contract_payment(contract.ptr, contractLen, &status);

            // Check the result
            assert(result == 1, "Expected result to be 1");
            assert(status == 0, "Expected status to be 0");
        }
        { // Remove bills by contract.

            uint result = remove_bills_by_contract(contract.ptr, contractLen);

            // Check the result
            assert(result == 1, "Expected result to be 1");
        }
    }
}

alias Store = WalletStorage;
struct WalletStorage {
    StdSecureWallet wallet;
    enum {
        accountfile = "account".setExtension(FileExtension.hibon), /// account file name
        walletfile = "wallet".setExtension(
                FileExtension.hibon), /// wallet file name
        devicefile = "device".setExtension(FileExtension.hibon), /// device file name
    }
    string wallet_data_path;
    this(const char[] walletDataPath) {
        import std.stdio;

        wallet_data_path = walletDataPath.idup;
        writefln("CREATE %s", walletDataPath);
        import std.file;

        if (!wallet_data_path.exists) {
            wallet_data_path.mkdirRecurse;
        }
        if (isWalletExist) {
            read;
        }
    }

    string path(string filename) const pure {
        return buildPath(wallet_data_path, filename);
    }

    bool isWalletExist() const {
        return only(accountfile, walletfile, devicefile)
            .map!(file => path(file).exists)
            .any;
    }

    void write() const {
        // Create a hibon for wallet data.

        path(devicefile).fwrite(wallet.pin);
        path(accountfile).fwrite(wallet.account);
        path(walletfile).fwrite(wallet.wallet);

    }

    void read() {
        auto _pin = path(devicefile).fread!DevicePIN;
        auto _wallet = path(walletfile).fread!RecoverGenerator;
        auto _account = path(accountfile).fread!AccountDetails;
        wallet = StdSecureWallet(_pin, _wallet, _account);

    }

    bool remove() const {
        if (wallet_data_path.exists) {

            try {
                only(accountfile, walletfile, devicefile)
                    .each!(file => path(file).remove);
                //wallet_data_path.rmdir;
                return 1;
            }
            catch (Exception e) {
                last_error = e;
                return false;
            }
        }
        return false;
    }
}

unittest {
    import std.stdio;
    import std.exception;

    const work_path = new_test_path;
    scope (success) {
        work_path.rmdirRecurse;
    }
    scope (failure) {
        writefln("failed work_path %s", work_path);
    }
    { // Write wallet file.

        // Path to stored wallet data.
        const walletDataPath = work_path;

        auto strg = new WalletStorage(walletDataPath);

        assertNotThrown(strg.write(), "Expect write result is true");
    }

    { // Read wallet file.

        // Path to stored wallet data.
        const walletDataPath = work_path;

        auto strg = new WalletStorage(walletDataPath);

        StdSecureWallet secure_wallet;

        assertNotThrown(strg.read(), "Expect read result is true");
    }

    { // Check if wallet file is exist.

        // Path to stored wallet data.
        const walletDataPath = work_path;

        auto strg = new WalletStorage(walletDataPath);
        bool result = strg.isWalletExist();
        assert(result, "Expect read result is true");
    }

    { // Delete wallet file.

        // Path to stored wallet data.
        const walletDataPath = work_path;

        auto strg = new WalletStorage(walletDataPath);
        bool result = strg.remove();
        assert(result, "Expect read result is true");
    }

}

version (unittest) {
    import std.file;
    import std.conv : to;

    string new_test_path(string func = __FUNCTION__, const size_t line = __LINE__) {
        const result_path = [deleteme, func, line.to!string].join("_");
        result_path.mkdirRecurse;
        return result_path;
    }
}
