module tagion.mobile.WalletWrapperSdk;

import tagion.mobile.DocumentWrapperApi;

// import tagion.mobile.WalletStorage;
import core.runtime : rt_init, rt_term;
import core.stdc.stdlib;
import std.array;
import std.random;
import std.stdint;
import std.string : fromStringz, toStringz;
import tagion.hibon.Document;

//import std.stdio;
import core.stdc.string;
import std.algorithm;
import std.file : exists, remove;
import std.path;
import std.range;
import std.string : splitLines;
import tagion.basic.Types : Buffer, FileExtension;
import tagion.communication.HiRPC;
import tagion.crypto.Cipher;
import tagion.crypto.SecureNet;
import tagion.crypto.Types : Pubkey;
import tagion.crypto.aes.AESCrypto;
import tagion.hibon.HiBON;
import tagion.hibon.HiBONFile : fread, fwrite;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord : HiBONRecord;
import tagion.script.TagionCurrency;
import tagion.script.common;
import tagion.utils.StdTime;
import tagion.wallet.AccountDetails;
import tagion.wallet.KeyRecover;
import Wallet = tagion.wallet.SecureWallet;
import tagion.wallet.WalletException;
import tagion.basic.tagionexceptions : Check;
import tagion.wallet.WalletRecords : DevicePIN, RecoverGenerator;
import tagion.tools.revision;

extern (C) export immutable string TAGION_HASH = revision_info[3];

/// Used for describing the d-runtime status
enum DrtStatus {
    DEFAULT_STS,
    STARTED,
    TERMINATED
}
/// Variable, which represents the d-runtime status
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
    enum : uint {
        ERROR = 0,
        SUCCESS = 1,
        PAYMENT_ERROR = 2,
        NOT_LOGGED_IN = 9,
        DART_UPDATE_REQUIRED = 16,
    }

    export const(char)* tagion_revision() {
        return revision_text.toStringz;
    }

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
        debug(android){
            import tagion.mobile.mobilelog : write_log;
            write_log("WalletWrapperSdk wallet_storage_init");
        } 
        const directoryPath = cast(char[])(pathPtr[0 .. pathLen]);
        if (directoryPath.length > 0) {
            // Full path to stored wallet data.
            const walletDataPath = directoryPath;
            __wallet_storage = new WalletStorage(walletDataPath);
            return SUCCESS;
        }

        return ERROR;
    }

    // Check if wallet was already created.
    export uint wallet_check_exist() {
        return __wallet_storage.isWalletExist();
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

            Check!(WalletException)(saltPtr is null && saltLen is 0 || saltPtr !is null, "Casting went wrong");

            auto salt = cast(char[]) saltPtr[0 .. saltLen];
            scope (exit) {
                pincode[] = 0;
                mnemonic[] = 0;
                salt[] = 0;
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
            return ERROR;
        }
        return SUCCESS;
    }

    export uint wallet_login(const uint8_t* pincodePtr, const uint32_t pincodeLen) nothrow {

        // Restore data from ponters.
        try {
            auto pincode = cast(char[])(pincodePtr[0 .. pincodeLen]);
            scope (exit) {
                pincode[] = 0;
            }

            __wallet_storage.read;
            return __wallet_storage.wallet.login(pincode);
        }
        catch (Exception e) {
            last_error = e;
        }
        return ERROR;
    }

    export uint wallet_logout() nothrow {
        if (__wallet_storage.wallet.isLoggedin()) {
            __wallet_storage.wallet.logout();
            // Set wallet to default.
            __wallet_storage.wallet = __wallet_storage.wallet.init;
            return SUCCESS;
        }
        return ERROR;
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
            return SUCCESS;
        }
        return ERROR;
    }

    export uint validate_pin(const uint8_t* pincodePtr, const uint32_t pincodeLen) {
        // Restore data from ponters.
        const pincode = cast(char[])(pincodePtr[0 .. pincodeLen]);

        if (__wallet_storage.wallet.isLoggedin()) {
            return __wallet_storage.wallet.checkPincode(pincode);
        }
        return ERROR;
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
                version (NET_HACK) {
                    __wallet_storage.read;
                }
                // Since secure_wallet do logout after pincode change
                // we need to perform a login manually.
                __wallet_storage.wallet.login(newPincode);
                return SUCCESS;
            }
        }
        return ERROR;
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
            const doc = Document(nftBuff);

            SignedContract signed_contract;

            try {
                import tagion.hibon.HiBONRecord;

                if (doc.getType == "createNFT") {
                    const is_created = __wallet_storage.wallet.createNFT(doc, Document[].init, signed_contract);
                    if (!is_created) {
                        return ERROR;
                    }

                }
                else if (doc.getType == "NFTTransfer") {
                    auto script = doc["script"].get!Document;
                    auto inputs = doc["inputs"].get!Document[].map!(e => e.get!Document).array;
                    const is_created = __wallet_storage.wallet.createNFT(script, inputs, signed_contract);
                    if (!is_created) {
                        return ERROR;
                    }
                }
                else {
                    return ERROR;
                }
            }
            catch (Exception e) {
                return ERROR;
            }

            const contract_net = __wallet_storage.wallet.net;
            const hirpc = HiRPC(contract_net);
            const contract = hirpc.submit(signed_contract);
            const contract_doc = contract.toDoc;
            const nftDocId = recyclerDoc.create(contract_doc);

            // Save wallet state to file.
            __wallet_storage.write;
            version (NET_HACK) {
                __wallet_storage.read;
            }
            *signedContractPtr = nftDocId;
            return SUCCESS;
        }
        return ERROR;
    }

    export uint create_contract(
            uint32_t* contractPtr,
            const uint8_t* invoicePtr,
            const uint32_t invoiceLen,
            const double amount,
            double* fees,
            uint32_t errorLen,
            uint8_t* errorPtr,
    ) {

        immutable invoiceBuff = cast(immutable)(invoicePtr[0 .. invoiceLen]);
        TagionCurrency tgn_fees;
        scope (exit) {
            *fees = tgn_fees.value;

        }

        if (!__wallet_storage.wallet.isLoggedin()) {
            return NOT_LOGGED_IN;
        }

        auto invoice = Invoice(Document(invoiceBuff));
        invoice.amount = TagionCurrency(amount);

        SignedContract signed_contract;
        const can_pay =
            __wallet_storage.wallet.payment([invoice], signed_contract, tgn_fees);
        if (can_pay) {
            const contract_net = __wallet_storage.wallet.net;
            const hirpc = HiRPC(contract_net);
            const contract = hirpc.submit(signed_contract);
            const contract_doc = contract.toDoc;
            const contractDocId = recyclerDoc.create(contract_doc);
            __wallet_storage.wallet.account.hirpcs ~= contract_doc;
            // Save wallet state to file.
            __wallet_storage.write;
            version (NET_HACK) {
                __wallet_storage.read;
            }

            *contractPtr = contractDocId;
            return SUCCESS;
        }
        auto error_result = new HiBON();
        if (can_pay.msg is null) {
            error_result["error"] = "error is null?";
        }
        else {
            error_result["error"] = can_pay.msg;
        }
        const errorDocId = recyclerDoc.create(Document(error_result));
        *errorPtr = cast(uint8_t) errorDocId;

        return PAYMENT_ERROR;
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
            version (NET_HACK) {
                __wallet_storage.read;
            }

            *invoicePtr = cast(uint8_t) invoiceDocId;
            return SUCCESS;
        }
        return ERROR;
    }

    export uint request_trt_update(uint8_t* requestPtr) {
        if (!__wallet_storage.wallet.isLoggedin()) {
        
            return NOT_LOGGED_IN;
        }
        const request = __wallet_storage.wallet.readIndicesByPubkey();
        const requestDocId = recyclerDoc.create(request.toDoc);
        *requestPtr = cast(uint8_t) requestDocId;
        return SUCCESS;
    }

    export uint update_trt_response(uint8_t* responsePtr, uint32_t responseLen, uint8_t* requestPtr) {
        import tagion.hibon.HiBONException;

        if (!__wallet_storage.wallet.isLoggedin()) {
            return NOT_LOGGED_IN;
        }
        immutable response = cast(immutable)(responsePtr[0 .. responseLen]);
        HiRPC hirpc = HiRPC(__wallet_storage.wallet.net);
        try {
            auto receiver = hirpc.receive(Document(response));
            if (!receiver.isResponse) {
                return ERROR;
            }
            const new_update = __wallet_storage.wallet.differenceInIndices(receiver);
            if (new_update !is HiRPC.Sender.init) {
                // return the new update save it 
                const dart_request_id = recyclerDoc.create(new_update.toDoc);
                *requestPtr = cast(uint8_t) dart_request_id;
                __wallet_storage.write;
                version (NET_HACK) {
                    __wallet_storage.read;
                }
                return DART_UPDATE_REQUIRED;
            }
            else {
                //no other modifies for the wallet needed save it
                __wallet_storage.write;
                version (NET_HACK) {
                    __wallet_storage.read;
                }
                return SUCCESS;
            }
        }
        catch (HiBONException e) {
            return ERROR;
        }
        return ERROR;
    }

    export uint update_dart_response(uint8_t* responsePtr, uint32_t responseLen) {
        import tagion.hibon.HiBONException;

        if (!__wallet_storage.wallet.isLoggedin()) {
            return NOT_LOGGED_IN;
        }

        immutable response = cast(immutable)(responsePtr[0 .. responseLen]);

        HiRPC hirpc = HiRPC(__wallet_storage.wallet.net);
        try {
            auto receiver = hirpc.receive(Document(response));
            if (!receiver.isResponse) {
                return ERROR;
            }
            const result = __wallet_storage.wallet.updateFromRead(receiver);
            if (result) {
                // Save wallet state to file.
                __wallet_storage.write;
                version (NET_HACK) {
                    __wallet_storage.read;
                }
                return SUCCESS;
            }
        }
        catch (HiBONException e) {
            return ERROR;
        }
        return ERROR;
    }

    export uint request_update(uint8_t* requestPtr) {

        if (!__wallet_storage.wallet.isLoggedin()) {
            return NOT_LOGGED_IN;

        }
        const request = __wallet_storage.wallet.getRequestUpdateWallet();
        const requestDocId = recyclerDoc.create(request.toDoc);
        *requestPtr = cast(uint8_t) requestDocId;
        return SUCCESS;
    }

    export uint update_response(uint8_t* responsePtr, uint32_t responseLen) {
        import tagion.hibon.HiBONException;

        immutable response = cast(immutable)(responsePtr[0 .. responseLen]);

        if (!__wallet_storage.wallet.isLoggedin()) {
            return NOT_LOGGED_IN;
        }

        HiRPC hirpc = HiRPC(__wallet_storage.wallet.net);
        try {
            auto receiver = hirpc.receive(Document(response));
            const result = __wallet_storage.wallet.setResponseUpdateWallet(receiver);

            if (result) {
                // Save wallet state to file.
                __wallet_storage.write;
                version (NET_HACK) {
                    __wallet_storage.read;
                }
                return SUCCESS;
            }
        }
        catch (HiBONException e) {
            return ERROR;
        }
        return ERROR;
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

    @safe
    export double get_total_balance() {
        const balance = __wallet_storage.wallet.total_balance();
        return balance.value;
    }

    export uint get_public_key(uint8_t* pubkeyPtr) {
        if (__wallet_storage.wallet.isLoggedin()) {
            const pubkey = __wallet_storage.wallet.getPublicKey();

            auto result = new HiBON();
            result["pubkey"] = pubkey;

            const pubkeyDocId = recyclerDoc.create(Document(result));

            *pubkeyPtr = cast(uint8_t) pubkeyDocId;

            return SUCCESS;
        }
        return ERROR;
    }

    export uint get_derivers_state(uint8_t* deriversStatePtr) {
        if (__wallet_storage.wallet.isLoggedin()) {
            const deriversState = __wallet_storage.wallet.getDeriversState();

            auto result = new HiBON();
            result["derivers_state"] = deriversState;

            const deviversStateDocId = recyclerDoc.create(Document(result));

            *deriversStatePtr = cast(uint8_t) deviversStateDocId;

            return SUCCESS;
        }
        return ERROR;
    }

    export uint get_account(uint8_t* accountPtr) {
        if (__wallet_storage.wallet.isLoggedin()) {

            const accountDocId = recyclerDoc.create(__wallet_storage.wallet.account.toDoc);

            *accountPtr = cast(uint8_t) accountDocId;

            return SUCCESS;
        }
        return ERROR;
    }

    export uint get_backup(uint8_t* backupPtr) {
        if (__wallet_storage.wallet.isLoggedin()) {
            const encrAccount = __wallet_storage.wallet.getEncrAccount();
            const backupDocId = recyclerDoc.create(encrAccount.toDoc);

            *backupPtr = cast(uint8_t) backupDocId;

            return SUCCESS;
        }
        return ERROR;
    }

    /** 
     * Set the backup account.hibon for the wallet
     * Params:
     *   backupPtr = 
     *   backupLen = 
     * Returns: 
     */
    export uint set_backup(const uint8_t* backupPtr, const uint32_t backupLen) {

        immutable account = cast(immutable)(backupPtr[0 .. backupLen]);

        if (__wallet_storage.wallet.isLoggedin()) {

            try {
                Document import_doc = Document(account);

                Document unencrypted_doc = import_doc;
                //decrypt
                if (import_doc.isRecord!(Cipher.CipherDocument)) {
                    Cipher cipher;
                    unencrypted_doc = cipher.decrypt(__wallet_storage.wallet.net, Cipher.CipherDocument(import_doc));
                } 

                if (unencrypted_doc.isRecord!AccountDetails) {
                    // not encrypted account backup
                    __wallet_storage.wallet.setAccount(unencrypted_doc);
                }
                else {
                    import tagion.wallet.prior.AccountDetails : PriorAccountDetails = AccountDetails;
                    import tagion.wallet.prior.migrate;
                    auto prior_account = PriorAccountDetails(unencrypted_doc);

                    auto new_account_doc = prior_account.migrate.toDoc;
                    __wallet_storage.wallet.setAccount(new_account_doc);
                }
                __wallet_storage.write;
                version (NET_HACK) {
                    __wallet_storage.read;
                }
            } catch (Exception e) {
                return ERROR;
            }
            return SUCCESS;
        }
        return ERROR;
    }

    export uint add_bill(const uint8_t* billPtr, const uint32_t billLen) {

        immutable billBuffer = cast(immutable)(billPtr[0 .. billLen]);

        if (__wallet_storage.wallet.isLoggedin()) {
            auto bill = TagionBill(Document(billBuffer));
            __wallet_storage.wallet.account.add_bill(bill);
            return SUCCESS;
        }
        return ERROR;
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

            return SUCCESS;
        }
        return ERROR;
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
            return SUCCESS;
        }
        return ERROR;
    }

    static sdt_t dummy_time;
    // DUMMY FUNCTION
    uint get_history(uint from, uint count, uint32_t* historyId) {

        debug(android){
            import tagion.mobile.mobilelog : write_log;
            write_log("GET HISTORY");
        }
        version (WALLET_HISTORY_DUMMY) {
            if (dummy_time == sdt_t.init) {
                dummy_time = currentTime();
            }

            DummyHistGen hist_gen;

            WHistory hist;
            hist_gen.popFront();
            if (count == 0) {
                hist.items = hist_gen.drop(from).array;
            }
            else {
                hist.items = hist_gen.drop(from).take(count).array;
            }

            *historyId = recyclerDoc.create(hist.toDoc);
        }
        else {
            assert(__wallet_storage !is null, "The Wallet storage was not initialised");

            WHistory hist;

            if (count == 0) {
                hist.items = __wallet_storage.wallet.account.reverse_history.drop(from)
                    .map!(i => WHistoryItem(i, __wallet_storage.wallet.net))
                    .array;
            }
            else {
                hist.items = __wallet_storage.wallet.account.reverse_history.drop(from).take(count)
                    .map!(i => WHistoryItem(i, __wallet_storage.wallet.net))
                    .array;
            }

            *historyId = recyclerDoc.create(hist.toDoc);
        }

        return SUCCESS;
    }
}

import tagion.hibon.HiBONRecord;
import tagion.dart.DARTBasic;

struct WHistoryItem {
    long amount;
    long balance;
    long fee;
    int status;
    int type;
    sdt_t timestamp;
    Pubkey pubkey;
    DARTIndex index; // The index of the output bill.

    mixin HiBONRecord!(q{
        this(HistoryItem item, const(SecureNet) net) {
            this.amount = item.bill.value.units;
            this.balance = item.balance.units;
            this.fee = item.fee.units;
            this.status = item.status;
            this.type = item.type;
            this.timestamp = item.bill.time;
            this.pubkey = item.bill.owner;
            this.index = dartIndex(net, item.bill);
        }
    });
}

struct WHistory {
    WHistoryItem[] items;
    mixin HiBONRecord;
}

pragma(msg, "remove wrapper dummy history");
struct DummyHistGen {
    import tagion.utils.Random;

    enum max_length = 37;

    Random!uint rnd = Random!uint(42);

    WHistoryItem genHistItem() {
        WHistoryItem hist_item;
        with (hist_item) {
            amount = rnd.value;
            balance = rnd.value;
            fee = rnd.value;
            status = rnd.value % 2;
            type = rnd.value % 2;
            timestamp = dummy_time;
            pubkey = Pubkey(rnd.take(33).map!(i => cast(ubyte)(i)).array.idup);
            index = DARTIndex(rnd.take(32).map!(i => cast(ubyte)(i)).array.idup);
        }
        return hist_item;
    }

    int i = 0;

    bool empty() => i > max_length;
    WHistoryItem _front;
    void popFront() {
        _front = genHistItem();
        i++;
    }

    WHistoryItem front() => _front;
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
        assert(wallet_create(pin_copy.ptr, pincodeLen, mnemonic.ptr, mnemonicLen, const(uint8_t*).init, uint32_t.init));
        pin_copy = pincode.dup;
        assert(wallet_login(pin_copy.ptr, pincodeLen));

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
    import std.range : zip;
    import std.string : representation;

    auto bill_amounts = [200, 500, 100].map!(a => a.TGN);
    [200, 500, 100]
        .map!(value => value.TGN)
        .map!(value => __wallet_storage.wallet.requestBill(value))
        .each!(bill => __wallet_storage.wallet.addBill(bill));

    const net = new StdHashNet;
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
    const uint32_t errorLen = 0;
    uint8_t errorPtr;

    uint32_t contractDocId;

    { // Create a contract.
        double fees;
        const uint result = create_contract(&contractDocId, invoice.ptr, invoiceLen, contAmount, &fees, errorLen, &errorPtr);
        // Check the result
        assert(result == 1, "Expected result to be 1");

        // Verify that invoiceDocId is non-zero
        assert(contractDocId != 0, "Expected non-zero contractDocId");
    }

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
        uint8_t backupDocId;
        uint getBackupResult = get_backup(&backupDocId);

        // Check the result
        assert(getBackupResult == 1, "Expected result to be 1");

        // Verify that invoiceDocId is non-zero
        assert(backupDocId != 0, "Expected non-zero backupDocId");

        auto backupDoc = recyclerDoc(backupDocId);

        // Derivers input data.
        const uint8_t[] backup = cast(uint8_t[])(backupDoc.serialize);
        const uint32_t backupLen = cast(uint32_t) backup.length;

        uint setBackupResult = set_backup(backup.ptr, backupLen);

        // Check the result
        assert(setBackupResult == 1, "Expected result to be 1");
    }

    { // Get derivers state.
        uint8_t deriversDocId;
        uint getDResult = get_derivers_state(&deriversDocId);

        // Check the result
        assert(getDResult == 1, "Expected result to be 1");

        // Verify that invoiceDocId is non-zero
        assert(deriversDocId != 0, "Expected non-zero deriversDocId");
    }

    { // Get Account
        uint8_t accountDocId;
        uint getAResult = get_account(&accountDocId);

        // Check the result
        assert(getAResult == 1, "Expected result to be 1");

        // Verify that invoiceDocId is non-zero
        assert(accountDocId != 0, "Expected non-zero accountDocId");
    }

    { // Ulock bills by contract

        uint result = ulock_bills_by_contract(contract.ptr, contractLen);

        // Check the result
        assert(result == 1, "Expected result to be 1");
    }

    { // Check contract payment

        uint8_t status;

        uint result = check_contract_payment(contract.ptr, contractLen, &status);

        // Check the result
        assert(result == 1, "Expected result to be 1");
        assert(status == 0, "Expected status to be 0");
    }

    { // Check Wallet history
        import std.stdio;
        import tagion.mobile.DocumentWrapperApi;

        uint32_t index;
        assert(get_history(0, 5, &index) == 1);

        assert(&index !is null);
        const(char*) jstr = doc_as_json(index);
        /* writeln(fromStringz(jstr)); */
        assert(jstr !is null);

        // writeln(fromStringz(jstr));
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
        import std.file;
        debug(android) {
            import tagion.mobile.mobilelog : log_file;
            writefln("creating file at %s", wallet_data_path);
            log_file = buildPath(wallet_data_path, "logfile.txt"); 
        }
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

        debug(android){
           import tagion.mobile.mobilelog : write_log;
            write_log("WalletStorage::write\n");
        }

        path(devicefile).fwrite(wallet.pin);
        path(accountfile).fwrite(wallet.account);
        path(walletfile).fwrite(wallet.wallet);

    }

    void read() {
        import tagion.hibon.HiBONException;

        version (NET_HACK) {
            auto _pin = path(devicefile).fread!DevicePIN;
            auto _wallet = path(walletfile).fread!RecoverGenerator;

            AccountDetails _account;
            try {
                _account = path(accountfile).fread!AccountDetails;
            }
            catch(HiBONRecordTypeException) {
                import prior = tagion.wallet.prior.AccountDetails;
                import tagion.wallet.prior.migrate;

                auto prior_account = path(accountfile).fread!(prior.AccountDetails);

                _account = migrate(prior_account);
            }

            if (wallet.net !is null) {
                auto __net = cast(shared(StdSecureNet)) wallet.net;
                scope (exit) {
                    __net = null;
                }
                auto copied_net = new StdSecureNet(__net);
                wallet = StdSecureWallet(_pin, _wallet, _account);

                wallet.set_net(copied_net);
            }
            else {
                wallet = StdSecureWallet(_pin, _wallet, _account);
            }
        }
        else {
            auto _pin = path(devicefile).fread!DevicePIN;
            auto _wallet = path(walletfile).fread!RecoverGenerator;
            auto _account = path(accountfile).fread!AccountDetails;
            wallet = StdSecureWallet(_pin, _wallet, _account);
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
                return false;
            }
        }
        return false;
    }
}

unittest {
    import std.exception;
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
    import std.conv : to;
    import std.file;

    string new_test_path(string func = __FUNCTION__, const size_t line = __LINE__) {
        const result_path = [deleteme, func, line.to!string].join("_");
        result_path.mkdirRecurse;
        return result_path;
    }
}
