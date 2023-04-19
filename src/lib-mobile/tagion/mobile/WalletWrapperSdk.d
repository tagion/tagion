module tagion.mobile.WalletWrapperSdk;

import tagion.mobile.DocumentWrapperApi;
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
import std.file : fread = read, exists;

import tagion.wallet.WalletRecords : RecoverGenerator, DevicePIN, AccountDetails;

/// Used for describing the d-runtime status
enum DrtStatus {
    DEFAULT_STS,
    STARTED,
    TERMINATED
}
/// Variable, which repsresents the d-runtime status
__gshared DrtStatus __runtimeStatus = DrtStatus.DEFAULT_STS;

/// Functions called from d-lang through dart:ffi
extern (C) {

    /// Staritng d-runtime
    export static int64_t start_rt() {
        if (__runtimeStatus is DrtStatus.DEFAULT_STS) {
            __runtimeStatus = DrtStatus.STARTED;
            return rt_init;
        }
        return -1;
    }

    /// Terminating d-runtime
    export static int64_t stop_rt() {
        if (__runtimeStatus is DrtStatus.STARTED) {
            __runtimeStatus = DrtStatus.TERMINATED;
            return rt_term;
        }
        return -1;
    }

    export uint wallet_create(const uint8_t* pincodePtr,
        const uint32_t pincodeLen, const uint16_t* mnemonicPtr, const uint32_t mnemonicLen,
        const uint8_t* pathPtr, uint32_t pathLen) {
        // Restore data from pointers.  
        const pincode = cast(char[])(pincodePtr[0 .. pincodeLen]);
        const mnemonic = mnemonicPtr[0 .. mnemonicLen];
        const directoryPath = cast(char[])(pathPtr[0 .. pathLen]);

        // Create a wallet from inputs.
        auto wallet = SecureWallet!(StdSecureNet).createWallet(
            mnemonic,
            pincode
        );

        // TODO: add encryption for a file content.
        // Create a hibon for wallet data.
        auto result = new HiBON();
        result["pin"] = wallet.pin.toHiBON;
        result["account"] = wallet.account.toHiBON;

        // TODO: extract to a separate StorageProvider service.
        // Full path to stored wallet data.
        auto walletDataPath = directoryPath ~ "/twallet.hibon";

        try {
            // Write to the file
            walletDataPath.fwrite(result);
            return 1;
        }
        catch (Exception e) {
            return 0;
        }
    }

    export uint wallet_login(const uint8_t* pincodePtr, const uint32_t pincodeLen,
        const uint8_t* pathPtr, uint32_t pathLen) {

        // Restore data from ponters.
        const pincode = cast(char[])(pincodePtr[0 .. pincodeLen]);
        const directoryPath = cast(char[])(pathPtr[0 .. pathLen]);

        // Full path to stored wallet data.
        auto walletDataPath = directoryPath ~ "/twallet.hibon";

        if (exists(walletDataPath)) {
            immutable walletDataFile = cast(immutable(ubyte)[]) fread(walletDataPath);
            // TODO: add decryption for a file content.
            // Wallet data in HiBON format.
            auto parentHibon = Document(walletDataFile);
            auto devicePin = parentHibon["pin"].get!Document;
            auto account = parentHibon["account"].get!Document;

            auto secure_wallet = SecureWallet!(StdSecureNet)(DevicePIN(devicePin),
                RecoverGenerator.init, AccountDetails(account));

            if (secure_wallet.login(pincode)) {
                return 1;
            }
        }

        return 0;
    }

    // export uint logout_wallet() {
    // }

    // export uint delete_wallet(uint32_t walletId) {
    // }

    // export uint validate_pin(uint8_t* pinCode, uint32_t pinLen) {
    // }

    // export uint change_pin(uint8_t* newPinCodePtr) {
    // }

    // export uint create_contract(uint8_t* result, uint8_t* invoice, uint64_t amount) {
    // }

    // export uint create_invoice(uint8_t* result, uint64_t amount, char* label, labelLen) {
    // }

    // export uint request_update(uint8_t* result) {
    // }

    // export uint update_response(uint8_t* response, uint32_t responseLen) {
    // }

    // export ulong get_locked_balance() {
    // }

    // export ulong get_balance() {
    // }

    // export uint get_public_key() {
    // }

    // export uint get_derivers(uint8_t* result) {
    // }

    // export uint set_derivers(uint8_t* derivers) {
    // }

    // export uint add_bills(uint8_t* bills, uint32_t billsLen) {
    // }

    // export uint remove_bills(uint8_t* contract) {
    // }

    // export uint ulock_bills(uint8_t* contract) {
    // }

    // export uint check_contract_payment(uint8_t* contract, uint8_t* status, uint64_t* amount) {
    // }

    // export uint check_invoice_payment(uint8_t* invoice, uint8_t* status, uint64_t* amount) {
    // }
}

unittest {
    printf("Unit test");
}
