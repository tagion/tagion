module tagion.mobile.WalletWrapperSdk;

import tagion.mobile.DocumentWrapperApi;

import tagion.mobile.WalletStorage;
import tagion.hibon.Document;
import core.runtime : rt_init, rt_term;
import core.stdc.stdlib;
import std.stdint;
import std.string : toStringz, fromStringz;
import std.array;
import std.random;
import tagion.wallet.SecureWallet;
import tagion.script.TagionCurrency;
import tagion.script.StandardRecords;
import tagion.communication.HiRPC;
import tagion.hibon.HiBON;
import std.stdio;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord : fwrite;
import tagion.basic.Types : Buffer;
import tagion.crypto.Types : Pubkey;
import tagion.crypto.aes.AESCrypto;
import tagion.crypto.SecureNet : StdSecureNet, BadSecureNet;
import tagion.crypto.SecureNet;
import tagion.wallet.KeyRecover;
import std.file : fread = read, exists, remove;
import core.stdc.string;

import tagion.wallet.WalletRecords : RecoverGenerator, DevicePIN, AccountDetails;
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
static __secure_wallet = SecureWallet!(StdSecureNet)(DevicePIN.init,
    RecoverGenerator.init, AccountDetails.init);
// Storage global variable.
static WalletStorage __wallet_storage = null;

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
        __secure_wallet = SecureWallet!(StdSecureNet)(DevicePIN.init,
            RecoverGenerator.init, AccountDetails.init);
    }

    export uint wallet_storage_init(const uint8_t* pathPtr, uint32_t pathLen) {
        const directoryPath = cast(char[])(pathPtr[0 .. pathLen]);
        // Full path to stored wallet data.
        const walletDataPath = directoryPath ~ "/twallet.hibon";

        __wallet_storage = new WalletStorage(walletDataPath);
        return 1;
    }

    export uint wallet_check_exist() {
        return __wallet_storage.isWalletExist();
    }

    export uint wallet_create(const uint8_t* pincodePtr,
        const uint32_t pincodeLen, const uint16_t* mnemonicPtr, const uint32_t mnemonicLen) {
        // Restore data from pointers.  
        const pincode = cast(char[])(pincodePtr[0 .. pincodeLen]);
        const mnemonic = mnemonicPtr[0 .. mnemonicLen];

        // Create a wallet from inputs.
        __secure_wallet = SecureWallet!(StdSecureNet).createWallet(
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

    export uint wallet_delete() {
        // Try to remove wallet file.
        if (__wallet_storage.remove()) {
            __secure_wallet.logout();
            // Set wallet to default.
            defaultWallet();
            return 1;
        }
        return 0;
    }

    export uint validate_pin(uint8_t* pincodePtr, uint32_t pincodeLen) {
        // Restore data from ponters.
        const pincode = cast(char[])(pincodePtr[0 .. pincodeLen]);

        if (__secure_wallet.isLoggedin()) {
            return __secure_wallet.checkPincode(pincode);
        }
        return 0;
    }

    // TODO: Get info if it's possible to change a pincode without providing a current one.
    export uint change_pin(uint8_t* pincodePtr, uint32_t pincodeLen, uint8_t* newPincodePtr, uint32_t newPincodeLen) {
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

    export uint create_contract(uint8_t* contractPtr, uint8_t* invoicePtr, uint32_t invoiceLen, uint64_t amount) {

        immutable invoiceBuff = cast(immutable)(invoicePtr[0 .. invoiceLen]);

        if (__secure_wallet.isLoggedin()) {
            auto invoice = Invoice(Document(invoiceBuff)[0].get!Document);
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

    export uint create_invoice(uint8_t* invoicePtr, uint64_t amount, char* labelPtr, uint32_t labelLen) {

        immutable label = cast(immutable)(labelPtr[0 .. labelLen]);

        if (__secure_wallet.isLoggedin()) {
            auto invoice = SecureWallet!(StdSecureNet).createInvoice(label,
                (cast(ulong) amount).TGN);
            __secure_wallet.registerInvoice(invoice);

            HiBON hibon = new HiBON();
            hibon[0] = invoice.toDoc;

            const invoiceDocId = recyclerDoc.create(Document(hibon));
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

    export ulong get_locked_balance() {
        const balance = __secure_wallet.locked_balance();
        return cast(ulong) balance.tagions;
    }

    export ulong get_balance() {
        const balance = __secure_wallet.available_balance();
        return cast(ulong) balance.tagions;
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

    export uint get_derivers(uint8_t* deriversPtr) {
        if (__secure_wallet.isLoggedin()) {
            const encrDerivers = __secure_wallet.getEncrDerivers();
            const deviversDocId = recyclerDoc.create(Document(encrDerivers.toHiBON));

            *deriversPtr = cast(uint8_t) deviversDocId;

            return 1;
        }
        return 0;
    }

    export uint set_derivers(uint8_t* deriversPtr, uint32_t deriversLen) {

        immutable encDerivers = cast(immutable)(deriversPtr[0 .. deriversLen]);

        if (__secure_wallet.isLoggedin()) {
            __secure_wallet.setEncrDerivers(Cipher.CipherDocument(Document(encDerivers)));
            return 1;
        }
        return 0;
    }

    export uint add_bill(uint8_t* billPtr, uint32_t billLen) {

        immutable billBuffer = cast(immutable)(billPtr[0 .. billLen]);

        if (__secure_wallet.isLoggedin()) {
            auto bill = StandardBill(Document(billBuffer));
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

    // TODO: add to account_details ability to remove bills by its hashes. 
    export uint remove_bills_by_contract(uint8_t* contractPtr, uint32_t contractLen) {
        // Collect input and output keys from the contract.
        // Iterate them and call remove on each.

        immutable contractBuffer = cast(immutable)(contractPtr[0 .. contractLen]);

        if (__secure_wallet.isLoggedin()) {

            const net = new StdHashNet;

            auto contractDoc = Document(contractBuffer);

            // Contract inputs.
            const messageTag = "$msg";
            const paramsTag = "params";

            auto messageDoc = contractDoc[messageTag].get!Document;
            auto paramsDoc = messageDoc[paramsTag].get!Document;
            auto sContract = SignedContract(paramsDoc);

            foreach (billHash; sContract.contract.inputs) {
                // TODO: ask Carsten to add remove_bill_by_hash impl to AccountDetails.
                // __secure_wallet.account.remove_bill_by_hash(billHash, net);
            }

            return 1;
        }
        return 0;
    }

    export uint ulock_bill(uint8_t* billHashPtr, uint32_t billHashLen) {

        immutable billHash = cast(immutable)(billHashPtr[0 .. billHashLen]);

        if (__secure_wallet.isLoggedin()) {
            const net = new StdHashNet;
            // TODO: ask Carsten to add unlock_bill_by_hash impl to AccountDetails.
            // __secure_wallet.account.unlock_bill_by_hash(billHash, net);
            return 1;
        }
        return 0;
    }

    export uint ulock_bills_by_contract(uint8_t* contractPtr, uint32_t contractLen) {

        immutable contractBuffer = cast(immutable)(contractPtr[0 .. contractLen]);

        if (__secure_wallet.isLoggedin()) {

            const net = new StdHashNet;

            auto contractDoc = Document(contractBuffer);

            // Contract inputs.
            const messageTag = "$msg";
            const paramsTag = "params";

            auto messageDoc = contractDoc[messageTag].get!Document;
            auto paramsDoc = messageDoc[paramsTag].get!Document;
            auto sContract = SignedContract(paramsDoc);

            foreach (billHash; sContract.contract.inputs) {
                // TODO: ask Carsten to add unlock_bill_by_hash impl to AccountDetails.
                // __secure_wallet.account.unlock_bill_by_hash(billHash, net);
            }

            return 1;
        }
        return 0;
    }

    // export uint check_contract_payment(uint8_t* contract, uint8_t* status, uint64_t* amount) {
    // }

    // export uint check_invoice_payment(uint8_t* invoice, uint8_t* status, uint64_t* amount) {
    // }
}

unittest {
    printf("Unit test");
}
