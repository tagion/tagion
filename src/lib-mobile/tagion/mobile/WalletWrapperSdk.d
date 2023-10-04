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
import std.stdio;
import std.path;
import std.range;
import std.algorithm;
import std.file : exists, remove;
import core.stdc.string;

import Wallet = tagion.wallet.SecureWallet;
import tagion.script.TagionCurrency;
import tagion.script.common;
import tagion.wallet.AccountDetails;
import tagion.communication.HiRPC;
import tagion.hibon.HiBON;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord : fwrite, fread, HiBONRecord;
import tagion.basic.Types : Buffer, FileExtension;
import tagion.crypto.Types : Pubkey;
import tagion.crypto.aes.AESCrypto;
import tagion.crypto.SecureNet : StdSecureNet, BadSecureNet;
import tagion.crypto.SecureNet;
import tagion.wallet.KeyRecover;
import tagion.wallet.WalletRecords : RecoverGenerator, DevicePIN;
import tagion.crypto.Cipher;

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

static __secure_wallet = StdSecureWallet(DevicePIN.init);

// Storage global variable.
static const(WalletStorage)* __wallet_storage;
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

    // Sets global wallet variable to init state.
    void defaultWallet() {
        __secure_wallet = StdSecureWallet(DevicePIN.init,
                RecoverGenerator.init, AccountDetails.init);
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

    export uint wallet_create(
            const uint8_t* pincodePtr,
            const uint32_t pincodeLen,
            const uint16_t* mnemonicPtr,
            const uint32_t mnemonicLen) {
        // Restore data from pointers.  
        const pincode = cast(char[])(pincodePtr[0 .. pincodeLen]);
        const mnemonic = mnemonicPtr[0 .. mnemonicLen];

        // Create a wallet from inputs.
        __secure_wallet = StdSecureWallet.createWallet(
                mnemonic,
                pincode
        );

        return __wallet_storage.write(__secure_wallet);

    }

    export uint wallet_login(const uint8_t* pincodePtr, const uint32_t pincodeLen) {

        // Restore data from ponters.
        const pincode = cast(char[])(pincodePtr[0 .. pincodeLen]);

        if (__wallet_storage.read(__secure_wallet)) {
            return __secure_wallet.login(pincode);
        }
        return 0;
    }

    export uint wallet_logout() {
        if (__secure_wallet.isLoggedin()) {
            __secure_wallet.logout();
            // Set wallet to default.
            defaultWallet();
            return 1;
        }
        return 0;
    }

    export uint wallet_check_login() {
        return __secure_wallet.isLoggedin();
    }

    export uint wallet_delete() {
        // Try to remove wallet file.
        if (__wallet_storage !is null && __wallet_storage.remove()) {
            __secure_wallet.logout();
            // Set wallet to default.
            defaultWallet();
            return 1;
        }
        return 0;
    }

    export uint validate_pin(const uint8_t* pincodePtr, const uint32_t pincodeLen) {
        // Restore data from ponters.
        const pincode = cast(char[])(pincodePtr[0 .. pincodeLen]);

        if (__secure_wallet.isLoggedin()) {
            return __secure_wallet.checkPincode(pincode);
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

        if (__secure_wallet.isLoggedin()) {
            if (__secure_wallet.changePincode(pincode, newPincode)) {
                __wallet_storage.write(__secure_wallet);
                // Since secure_wallet do logout after pincode change
                // we need to perform a login manualy.
                __secure_wallet.login(newPincode);
                return 1;
            }
        }
        return 0;
    }

    export uint create_contract(
            uint8_t* contractPtr,
            const uint8_t* invoicePtr,
            const uint32_t invoiceLen,
            const double amount) {

        immutable invoiceBuff = cast(immutable)(invoicePtr[0 .. invoiceLen]);

        if (__secure_wallet.isLoggedin()) {
            auto invoice = Invoice(Document(invoiceBuff));
            invoice.amount = TagionCurrency(amount);

            SignedContract signed_contract;

            if (__secure_wallet.payment([invoice], signed_contract)) {
                HiRPC hirpc;
                const sender = hirpc.action("transaction", signed_contract.toHiBON);
                const contractDocId = recyclerDoc.create(Document(sender.toHiBON));

                // Save wallet state to file.
                __wallet_storage.write(__secure_wallet);

                *contractPtr = cast(uint8_t) contractDocId;
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

        if (__secure_wallet.isLoggedin()) {
            auto invoice = StdSecureWallet.createInvoice(
                    label, amount.TGN);
            __secure_wallet.registerInvoice(invoice);

            const invoiceDocId = recyclerDoc.create(invoice.toDoc);
            // Save wallet state to file.
            __wallet_storage.write(__secure_wallet);

            *invoicePtr = cast(uint8_t) invoiceDocId;
            return 1;
        }
        return 0;
    }

    export uint request_update(uint8_t* requestPtr) {

        if (__secure_wallet.isLoggedin()) {
            const request = __secure_wallet.getRequestUpdateWallet();
            const requestDocId = recyclerDoc.create(request.toDoc);
            *requestPtr = cast(uint8_t) requestDocId;
            return 1;
        }
        return 0;

    }

    export uint update_response(uint8_t* responsePtr, uint32_t responseLen) {

        immutable response = cast(immutable)(responsePtr[0 .. responseLen]);

        if (__secure_wallet.isLoggedin()) {

            HiRPC hirpc;
            auto receiver = hirpc.receive(Document(response));
            const result = __secure_wallet.setResponseUpdateWallet(receiver);

            if (result) {
                // Save wallet state to file.
                __wallet_storage.write(__secure_wallet);
                return 1;
            }
        }

        return 0;
    }

    @safe
    export double get_locked_balance() {
        const balance = __secure_wallet.locked_balance();
        return balance.value;
    }

    @safe
    export double get_balance() {
        const balance = __secure_wallet.available_balance();
        return balance.value;
    }

    export uint get_public_key(uint8_t* pubkeyPtr) {
        if (__secure_wallet.isLoggedin()) {
            const pubkey = __secure_wallet.getPublicKey();

            auto result = new HiBON();
            result["pubkey"] = pubkey;

            const pubkeyDocId = recyclerDoc.create(Document(result));

            *pubkeyPtr = cast(uint8_t) pubkeyDocId;

            return 1;
        }
        return 0;
    }

    export uint get_derivers_state(uint8_t* deriversStatePtr) {
        if (__secure_wallet.isLoggedin()) {
            const deriversState = __secure_wallet.getDeriversState();

            auto result = new HiBON();
            result["derivers_state"] = deriversState;

            const deviversStateDocId = recyclerDoc.create(Document(result));

            *deriversStatePtr = cast(uint8_t) deviversStateDocId;

            return 1;
        }
        return 0;
    }

    export uint get_derivers(uint8_t* deriversPtr) {
        if (__secure_wallet.isLoggedin()) {
            const encrDerivers = __secure_wallet.getEncrDerivers();
            const deviversDocId = recyclerDoc.create(Document(encrDerivers.toHiBON));

            *deriversPtr = cast(uint8_t) deviversDocId;

            return 1;
        }
        return 0;
    }

    export uint set_derivers(const uint8_t* deriversPtr, const uint32_t deriversLen) {

        immutable encDerivers = cast(immutable)(deriversPtr[0 .. deriversLen]);

        if (__secure_wallet.isLoggedin()) {
            __secure_wallet.setEncrDerivers(Cipher.CipherDocument(Document(encDerivers)));
            return 1;
        }
        return 0;
    }

    export uint add_bill(const uint8_t* billPtr, const uint32_t billLen) {

        immutable billBuffer = cast(immutable)(billPtr[0 .. billLen]);

        if (__secure_wallet.isLoggedin()) {
            auto bill = TagionBill(Document(billBuffer));
            __secure_wallet.account.add_bill(bill);
            return 1;
        }
        return 0;
    }

    export uint remove_bill(uint8_t* pubKeyPtr, uint32_t pubKeyLen) {
        immutable(ubyte)[] pubKey = cast(immutable(ubyte)[])(pubKeyPtr[0 .. pubKeyLen]);

        if (__secure_wallet.isLoggedin()) {
            const result = __secure_wallet.account.remove_bill(Pubkey(pubKey));
            return result;
        }
        return 0;
    }

    export uint remove_bills_by_contract(const uint8_t* contractPtr, const uint32_t contractLen) {
        // Collect input and output keys from the contract.
        // Iterate them and call remove on each.

        immutable contractBuffer = cast(immutable)(contractPtr[0 .. contractLen]);

        if (__secure_wallet.isLoggedin()) {

            auto contractDoc = Document(contractBuffer);

            // Contract inputs.
            const messageTag = "$msg";
            const paramsTag = "params";

            auto messageDoc = contractDoc[messageTag].get!Document;
            auto paramsDoc = messageDoc[paramsTag].get!Document;
            auto sContract = SignedContract(paramsDoc);

            import std.algorithm;

            sContract.contract.inputs.each!(hash => __secure_wallet.account.remove_bill_by_hash(hash));

            return 1;
        }
        return 0;
    }

    export uint ulock_bills_by_contract(const uint8_t* contractPtr, const uint32_t contractLen) {

        immutable contractBuffer = cast(immutable)(contractPtr[0 .. contractLen]);

        if (__secure_wallet.isLoggedin()) {

            auto contractDoc = Document(contractBuffer);

            // Contract inputs.
            const messageTag = "$msg";
            const paramsTag = "params";

            auto messageDoc = contractDoc[messageTag].get!Document;
            auto paramsDoc = messageDoc[paramsTag].get!Document;
            auto sContract = SignedContract(paramsDoc);

            import std.algorithm;

            sContract.contract.inputs.each!(hash => __secure_wallet.account.unlock_bill_by_hash(hash));

            return 1;
        }
        return 0;
    }

    export uint check_contract_payment(const uint8_t* contractPtr, const uint32_t contractLen, uint8_t* statusPtr) {
        immutable contractBuffer = cast(immutable)(contractPtr[0 .. contractLen]);

        if (__secure_wallet.isLoggedin()) {

            auto contractDoc = Document(contractBuffer);

            // Contract inputs.
            const messageTag = "$msg";
            const paramsTag = "params";

            auto messageDoc = contractDoc[messageTag].get!Document;
            auto paramsDoc = messageDoc[paramsTag].get!Document;
            auto sContract = SignedContract(paramsDoc);

            version (none) {
                int status = __secure_wallet.account.check_contract_payment(
                        sContract.contract.inputs, sContract.contract.output);

                *statusPtr = cast(uint8_t) status;
            }
            return 1;
        }
        return 0;
    }

    export uint check_invoice_payment(const uint8_t* invoicePtr, const uint32_t invoiceLen, double* amountPtr) {
        immutable invoiceBuffer = cast(immutable)(invoicePtr[0 .. invoiceLen]);

        if (__secure_wallet.isLoggedin()) {

            auto invoice = Invoice(Document(invoiceBuffer));
            auto amount = __secure_wallet.account.check_invoice_payment(invoice.pkey);

            *amountPtr = amount.value;

            return 1;
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
        const uint16_t[] mnemonic = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
        const uint32_t mnemonicLen = cast(uint32_t) mnemonic.length;

        // Call the wallet_create function
        const uint result = wallet_create(pincode.ptr, pincodeLen, mnemonic.ptr, mnemonicLen);

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
        assert(!__secure_wallet.isLoggedin);
    }

    { // Delete wallet.

        const result = wallet_delete();
        assert(result != 0, "Expected non-zero result");
        assert(!__secure_wallet.isLoggedin);
        assert(!__wallet_storage.isWalletExist);
    }

    { // Validate pin.

        const uint8_t[] pincode = cast(uint8_t[]) "1234".dup;
        const uint32_t pincodeLen = cast(uint32_t) pincode.length;
        const uint16_t[] mnemonic = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
        const uint32_t mnemonicLen = cast(uint32_t) mnemonic.length;

        // Call the wallet_create function
        wallet_create(pincode.ptr, pincodeLen, mnemonic.ptr, mnemonicLen);
        wallet_login(pincode.ptr, pincodeLen);

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
        assert(__secure_wallet.isLoggedin, "Expected wallet stays logged in");
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
    const net = new StdHashNet;
    auto gene = cast(Buffer) net.calcHash("gene".representation);
    const uint epoch = 42;

    import tagion.utils.Miscellaneous : hex;

    // Add the bills to the account with the derive keys
    version (none)
        with (__secure_wallet.account) {
            bills = zip(bill_amounts, derivers.byKey).map!(bill_derive => TagionBill(bill_derive[0],
            epoch, bill_derive[1], gene)).array;
        }

    auto invoiceDoc = recyclerDoc(invoiceDocId);

    // Contract input data.
    const uint8_t[] invoice = cast(uint8_t[])(invoiceDoc.serialize);
    const uint32_t invoiceLen = cast(uint32_t) invoice.length;
    const uint64_t contAmount = 100;

    uint8_t contractDocId;

    version (none) { // Create a contract.
        const uint result = create_contract(&contractDocId, invoice.ptr, invoiceLen, contAmount);

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
                with (__secure_wallet.account) {
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

struct WalletStorage {

    enum {
        accountfile = "account".setExtension(FileExtension.hibon), /// account file name
        walletfile = "wallet".setExtension(
                FileExtension.hibon), /// wallet file name
        devicefile = "device".setExtension(FileExtension.hibon), /// device file name
    }
    string wallet_data_path;
    this(const char[] walletDataPath) const pure nothrow {
        wallet_data_path = walletDataPath.idup;
    }

    string path(string filename) const pure {
        return buildPath(wallet_data_path, filename);
    }

    bool isWalletExist() const {
        return only(accountfile, walletfile, devicefile)
            .map!(file => path(file).exists)
            .any;
    }

    bool write(const StdSecureWallet secure_wallet) const {
        // Create a hibon for wallet data.
        try {

            path(devicefile).fwrite(secure_wallet.pin);
            path(accountfile).fwrite(secure_wallet.account);
            path(walletfile).fwrite(secure_wallet.wallet);
            return true;
        }
        catch (Exception e) {
            return false;
        }
    }

    bool read(ref StdSecureWallet secure_wallet) const {
        try {
            auto pin = path(devicefile).fread!DevicePIN;
            auto wallet = path(walletfile).fread!RecoverGenerator;
            auto account = path(accountfile).fread!AccountDetails;
            secure_wallet = StdSecureWallet(pin, wallet, account);
            return true;
        }
        catch (Exception e) {
            return false;
        }
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
                writefln("%s", e);
                return false;
            }
        }
        return false;
    }
}

unittest {
    import std.stdio;

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

        const secure_wallet = StdSecureWallet(DevicePIN.init,
                RecoverGenerator.init, AccountDetails.init);

        bool result = strg.write(secure_wallet);
        assert(result, "Expect write result is true");
    }

    { // Read wallet file.

        // Path to stored wallet data.
        const walletDataPath = work_path;

        auto strg = new WalletStorage(walletDataPath);

        StdSecureWallet secure_wallet;

        bool result = strg.read(secure_wallet);
        assert(result, "Expect read result is true");
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
