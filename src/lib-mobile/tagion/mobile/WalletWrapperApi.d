module tagion.mobile.WalletWrapperApi;

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
import tagion.script.prior.StandardRecords;
import tagion.communication.HiRPC;
import tagion.hibon.HiBON;
import std.stdio;
import tagion.hibon.HiBONJSON;
import tagion.basic.Types : Buffer;
import tagion.crypto.Types : Pubkey;
import tagion.crypto.aes.AESCrypto;
import tagion.crypto.SecureNet : StdSecureNet, BadSecureNet;
import tagion.crypto.SecureNet;
import tagion.wallet.KeyRecover;

import tagion.wallet.WalletRecords : RecoverGenerator, DevicePIN, AccountDetails;

/// Used for describing the d-runtime status
enum drtStatus {
    DEFAULT_STS,
    STARTED,
    TERMINATED
}
/// Variable, which repsresents the d-runtime status
__gshared drtStatus __runtimeStatus = drtStatus.DEFAULT_STS;

string[] parse_string(const char* str, const uint len) {
    string[] result;
    return result;
}

/// Functions called from d-lang through dart:ffi
version (D_BetterC) {
}
else {
extern (C):
}
/// Staritng d-runtime
export static int64_t start_rt() {
    if (__runtimeStatus is drtStatus.DEFAULT_STS) {
        __runtimeStatus = drtStatus.STARTED;
        return rt_init;
    }
    return -1;
}

/// Terminating d-runtime
export static int64_t stop_rt() {
    if (__runtimeStatus is drtStatus.STARTED) {
        __runtimeStatus = drtStatus.TERMINATED;
        return rt_term;
    }
    return -1;
}
//const uint8_t* data_ptr, const uint32_t len                                                  /// Not used
export uint wallet_create(const uint8_t* pincodePtr, const uint32_t pincodeLen, const uint32_t __aes_doc_id,
        const char* questionsPtr, const uint32_t qestionslen, const char* answersPtr,
        const uint32_t answerslen, uint32_t confidence) {
    immutable pincode = cast(immutable)(pincodePtr[0 .. pincodeLen]);

    const aes_doc_id = generateAESKey(0);
    const aes_key_data = recyclerDoc(aes_doc_id);

    immutable decr_pincode = decrypt(pincode, aes_key_data);
    immutable questions = cast(immutable)((questionsPtr[0 .. qestionslen]).split(";"));
    immutable answers = cast(immutable)((answersPtr[0 .. answerslen]).split(";"));
    auto wallet = SecureWallet!(StdSecureNet).createWallet(questions,
            answers, confidence, cast(immutable(char)[]) decr_pincode);

    auto recovery_id = recyclerDoc.create(Document(wallet.wallet.toHiBON));
    auto device_pin_id = recyclerDoc.create(Document(wallet.pin.toHiBON));
    auto account_id = recyclerDoc.create(Document(wallet.account.toHiBON));

    auto result = new HiBON();
    result["recovery"] = recovery_id;
    result["pin"] = device_pin_id;
    result["account"] = account_id;

    const doc_id = recyclerDoc.create(Document(result));
    return doc_id;
}

export uint invoice_create(const uint32_t doc_id, const uint32_t dev_pin_doc_id,
        const uint8_t* pincodePtr, const uint32_t pincodeLen,
        const uint32_t aes_doc_id, const uint64_t amount,
        const char* labelPtr, const uint32_t labelLen) {
    immutable device_pin_doc = recyclerDoc(dev_pin_doc_id);
    immutable pincode = cast(immutable)(pincodePtr[0 .. pincodeLen]);

    const aes_key_data = recyclerDoc(aes_doc_id);

    immutable decr_pincode = cast(immutable(char)[]) decrypt(pincode, aes_key_data);

    immutable label = cast(immutable)(labelPtr[0 .. labelLen]);
    const doc = recyclerDoc(doc_id);
    auto secure_wallet = SecureWallet!(StdSecureNet)(DevicePIN(device_pin_doc),
            RecoverGenerator.init, AccountDetails(doc));

    scope (success) {
        recyclerDoc.put(Document(secure_wallet.account.toHiBON), doc_id);
    }
    if (secure_wallet.login(decr_pincode)) {
        auto invoice = SecureWallet!(StdSecureNet).createInvoice(label,
                (cast(ulong) amount).TGN);
        secure_wallet.registerInvoice(invoice);
        HiBON hibon = new HiBON();
        hibon[0] = invoice.toDoc;
        const invoiceDocId = recyclerDoc.create(Document(hibon));
        return invoiceDocId;
    }
    return BAD_RESULT;
}

export uint contract_create(const uint32_t doc_id, const uint32_t dev_pin_doc_id, const uint32_t invoice_doc_id,
        const uint8_t* pincodePtr, const uint32_t pincodeLen, const uint32_t aes_doc_id) {
    immutable device_pin_doc = recyclerDoc(dev_pin_doc_id);
    immutable pincode = cast(immutable)(pincodePtr[0 .. pincodeLen]);

    const aes_key_data = recyclerDoc(aes_doc_id);

    immutable decr_pincode = cast(immutable(char)[]) decrypt(pincode, aes_key_data);

    const wallet_doc = recyclerDoc(doc_id);

    auto secure_wallet = SecureWallet!(StdSecureNet)(DevicePIN(device_pin_doc),
            RecoverGenerator.init, AccountDetails(wallet_doc));

    scope (success) {
        recyclerDoc.put(Document(secure_wallet.account.toHiBON), doc_id);
    }

    if (secure_wallet.login(decr_pincode)) {
        const invoice_doc = recyclerDoc(invoice_doc_id);
        const invoice = Invoice(invoice_doc[0].get!Document);

        SignedContract signed_contract;
        Invoice[1] orders = invoice;
        if (secure_wallet.payment(orders, signed_contract)) {
            HiRPC hirpc;
            const sender = hirpc.action("transaction", signed_contract.toHiBON);
            immutable data = Document(sender.toHiBON);
            const contract_doc_id = recyclerDoc.create(data);
            return contract_doc_id;
        }
    }
    return BAD_RESULT;
}

/// TODO: Check amount.
export uint contract_create_with_amount(const uint32_t wallet_doc_id,
        const uint32_t dev_pin_doc_id, const uint32_t invoice_doc_id,
        const uint8_t* pincodePtr, const uint32_t pincodeLen,
        const uint32_t aes_doc_id, const uint64_t amount) {
    immutable device_pin_doc = recyclerDoc(dev_pin_doc_id);
    immutable pincode = cast(immutable)(pincodePtr[0 .. pincodeLen]);
    const aes_key_data = recyclerDoc(aes_doc_id);
    immutable decr_pincode = cast(immutable(char)[]) decrypt(pincode, aes_key_data);

    const wallet_doc = recyclerDoc(wallet_doc_id);

    auto secure_wallet = SecureWallet!(StdSecureNet)(DevicePIN(device_pin_doc),
            RecoverGenerator.init, AccountDetails(wallet_doc));

    scope (success) {
        recyclerDoc.put(Document(secure_wallet.account.toHiBON), wallet_doc_id);
    }

    if (secure_wallet.login(decr_pincode)) {
        const invoice_doc = recyclerDoc(invoice_doc_id);
        auto invoice = Invoice(invoice_doc[0].get!Document);

        invoice.amount = TagionCurrency(amount);

        SignedContract signed_contract;

        if (secure_wallet.payment([invoice], signed_contract)) {
            HiRPC hirpc;
            const sender = hirpc.action("transaction", signed_contract.toHiBON);
            immutable data = Document(sender.toHiBON);
            const contract_doc_id = recyclerDoc.create(data);
            return contract_doc_id;
        }
    }
    return BAD_RESULT;
}

// export uint dev_put_invoice_to_bills(const uint32_t wallet_doc_id,
//         const uint32_t invoice_doc_id, const uint8_t* pincodePtr, const uint32_t pincodeLen)
// {
//     immutable pincode = cast(immutable(char)[])(pincodePtr[0 .. pincodeLen]);
//     const wallet_doc = recyclerDoc(wallet_doc_id);
//     auto secure_wallet = SecureWallet!(StdSecureNet)(wallet_doc);

//     scope (success)
//     {
//         recyclerDoc.put(Document(secure_wallet.wallet.toHiBON), wallet_doc_id);
//     }

//     if (secure_wallet.login(pincode))
//     {
//         import std.stdio;

//         const invoice_doc = recyclerDoc(invoice_doc_id);
//         const invoice = Invoice(invoice_doc[0].get!Document);

//         secure_wallet.put_invoice_to_bills(invoice);
//         return 1;
//     }
//     return BAD_RESULT;
// }

export ulong get_balance_available(const uint32_t doc_id) {
    const wallet_doc = recyclerDoc(doc_id);

    auto secure_wallet = SecureWallet!(StdSecureNet)(DevicePIN.init,
            RecoverGenerator.init, AccountDetails(wallet_doc));

    const balance = secure_wallet.available_balance();
    return cast(ulong) balance.units;
}

export ulong get_balance_locked(const uint32_t wallet_doc_id) {
    const wallet_doc = recyclerDoc(wallet_doc_id);

    auto secure_wallet = SecureWallet!(StdSecureNet)(DevicePIN.init,
            RecoverGenerator.init, AccountDetails(wallet_doc));

    const balance = secure_wallet.locked_balance();
    return cast(ulong) balance.units;
}

// export ulong get_lock_for_amount(const uint32_t wallet_doc_id, const uint64_t amount)
// {
//     const wallet_doc = recyclerDoc(wallet_doc_id);
//     auto secure_wallet = SecureWallet!(StdSecureNet)(wallet_doc);

//     const bills = secure_wallet.get_payment_bills(amount);
//     const lock_amount = secure_wallet.calcTotal(bills);
//     return lock_amount;
// }

export bool add_bill(const uint32_t wallet_doc_id, const uint32_t bill_doc_id) {
    const wallet_doc = recyclerDoc(wallet_doc_id);
    auto account = AccountDetails(wallet_doc);

    scope (success) {
        recyclerDoc.put(Document(account.toHiBON), wallet_doc_id);
    }

    const bill_doc = recyclerDoc(bill_doc_id);
    auto bill = StandardBill(bill_doc);

    account.add_bill(bill);
    return 1;
}

export bool remove_bill(const uint32_t wallet_doc_id, const uint8_t* data_ptr, const uint32_t len) {
    const wallet_doc = recyclerDoc(wallet_doc_id);
    auto account = AccountDetails(wallet_doc);

    scope (success) {
        recyclerDoc.put(Document(account.toHiBON), wallet_doc_id);
    }

    immutable(ubyte)[] data = cast(immutable(ubyte)[]) data_ptr[0 .. len];

    const result = account.remove_bill(Pubkey(data));
    return result;
}

export uint getRequestUpdateWallet(const uint32_t doc_id) {

    const account_doc = recyclerDoc(doc_id);

    auto secure_wallet = SecureWallet!(StdSecureNet)(DevicePIN.init,
            RecoverGenerator.init, AccountDetails(account_doc));

    const request = secure_wallet.getRequestUpdateWallet();
    const request_doc_id = recyclerDoc.create(request.toDoc);
    return request_doc_id;
}

export uint setResponseUpdateWallet(const uint32_t doc_id,
        const uint32_t dev_pin_doc_id, const uint32_t response_doc_id,
        const uint8_t* pincodePtr, const uint32_t pincodeLen, const uint32_t aes_doc_id) {

    const doc = recyclerDoc(doc_id);

    immutable pincode = cast(immutable)(pincodePtr[0 .. pincodeLen]);

    const aes_key_data = recyclerDoc(aes_doc_id);

    immutable decr_pincode = cast(immutable(char)[]) decrypt(pincode, aes_key_data);

    immutable device_pin_doc = recyclerDoc(dev_pin_doc_id);

    auto secure_wallet = SecureWallet!(StdSecureNet)(DevicePIN(device_pin_doc),
            RecoverGenerator.init, AccountDetails(doc));

    scope (success) {
        recyclerDoc.put(Document(secure_wallet.account.toHiBON), doc_id);
    }

    if (secure_wallet.login(decr_pincode)) {
        const response_doc = recyclerDoc(response_doc_id);

        HiRPC hirpc;

        auto receiver = hirpc.receive(response_doc);

        const result = secure_wallet.setResponseUpdateWallet(receiver);
        return cast(uint) result;
    }

    return BAD_RESULT;
}

export uint generateAESKey(const(uint32_t) aes_key_doc_id) {
    auto seed = new ubyte[32];
    scramble(seed);

    auto hibon = new HiBON;
    hibon["seed"] = seed.idup;
    if (aes_key_doc_id == 0) {
        return cast(uint) recyclerDoc.create(Document(hibon.serialize));
    }

    recyclerDoc.put(Document(hibon.serialize), aes_key_doc_id);
    return aes_key_doc_id;
}

export uint validate(const uint32_t doc_id, const uint32_t dev_pin_doc_id,
        const uint8_t* pincodePtr, const uint32_t pincodeLen, const uint32_t aes_doc_id,) {

    immutable pincode = cast(immutable)(pincodePtr[0 .. pincodeLen]);

    const aes_key_data = recyclerDoc(aes_doc_id);

    immutable decr_pincode = cast(immutable(char)[]) decrypt(pincode, aes_key_data);

    immutable device_pin_doc = recyclerDoc(dev_pin_doc_id);

    const doc = recyclerDoc(doc_id);

    auto secure_wallet = SecureWallet!(StdSecureNet)(DevicePIN(device_pin_doc),
            RecoverGenerator.init, AccountDetails(doc));

    if (secure_wallet.login(decr_pincode)) {
        return 1;
    }
    return 0;
}

import std.traits;

Buffer decrypt(Buffer encrypted_seed, Document aes_key_doc) {
    import std.digest.sha : SHA256;
    import std.digest;

    // auto aes_key_hibon = new HiBON(aes_key_doc);
    auto aes_seed = aes_key_doc["seed"].get!Buffer;
    alias AES = AESCrypto!256;

    /// Key.
    auto aes_key = digest!SHA256(aes_seed).idup;
    /// IV.
    auto aes_iv = digest!SHA256(aes_seed)[4 .. 4 + AES.BLOCK_SIZE].dup;

    ubyte[] result = [];
    /// Generated AES key.
    AES.decrypt(aes_key, aes_iv, encrypted_seed, result);

    return result.idup;
}
