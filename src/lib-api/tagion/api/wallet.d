/// API for using a wallet
module tagion.api.wallet;
import tagion.api.errors;
import tagion.api.hibon;
import tagion.wallet.Wallet;
import tagion.crypto.SecureNet;
import core.stdc.stdint;
import tagion.hibon.Document;
import tagion.script.TagionCurrency;
import tagion.utils.StdTime;
import tagion.crypto.Types : Pubkey;
import tagion.script.common : TagionBill;

import tagion.wallet.WalletRecords : DevicePIN, RecoverGenerator;
import tagion.wallet.AccountDetails;

version(C_API_DEBUG) {
import std.stdio;

}

extern (C):
version (unittest) {
}
else {
nothrow:
}


alias ApiWallet = Wallet!StdSecureNet;

enum MAGIC_WALLET = 0xA000_0001;
struct WalletT {
    int magic_byte = MAGIC_WALLET;
    void* wallet;
}
/** 
 * Create a new wallet instance
 * Params:
 *   wallet_instance = pointer to create the instance at
 * Returns: ErrorCode
 */
int tagion_wallet_create_instance(WalletT* wallet_instance) {
    try {
        if (wallet_instance is null) {
            return ErrorCode.error;
        }

        wallet_instance.wallet = cast(void*) new ApiWallet;
        version(C_API_DEBUG) {
            writefln("created wallet");
        }
    }
    catch(Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}
///
unittest {
    WalletT w;
    int rt = tagion_wallet_create_instance(&w);
    assert(rt == ErrorCode.none);
}

/** 
 * Create new wallet. Note requires post save of Account, RecoverGenerator and DevicePIN 
 * Params:
 *   wallet_instance = instance to the wallet 
 *   passphrase = pointer to the passphrase
 *   passphrase_len = length of the passphrase
 *   pincode = pointer to the pincode
 *   pincode_len = length of the pincode
 * Returns: ErrorCode
 */
int tagion_wallet_create_wallet(const(WalletT*) wallet_instance, 
                            const char* passphrase, 
                            const size_t passphrase_len,
                            const char* pincode,
                            const size_t pincode_len) {
    try {
    
        if (wallet_instance is null || wallet_instance.magic_byte != MAGIC_WALLET) {
            return ErrorCode.exception;
        }
        ApiWallet* w = cast(ApiWallet*) wallet_instance.wallet;
        auto _passphrase = passphrase[0..passphrase_len];
        auto _pincode = pincode[0..pincode_len];
        w.createWallet(_passphrase, _pincode);
    } 
    catch(Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
} 
///
unittest {
    WalletT w;
    int rt = tagion_wallet_create_instance(&w);
    assert(rt == ErrorCode.none);

    string passphrase = "some_passphrase";
    string pincode = "some_pincode";

    rt = tagion_wallet_create_wallet(&w, &passphrase[0], passphrase.length, &pincode[0], pincode.length);
    assert(rt == ErrorCode.none);
}

/** 
 * Read an already existing wallet based on wallet file buffers
 * Params:
 *   wallet_instance = instance to the wallet
 *   device_pin_buf = pointer to the DevicePIN
 *   device_pin_buf_len = length of the DevicePIN buf
 *   recover_generator_buf = pointer to the RecoverGenerator
 *   recover_generator_buf_length = length of the RecoverGenerator buf
 *   account_buf = pointer to the AccountDetails
 *   account_buf_len = length of the AccountDetails buffer
 * Returns: ErrorCode
 */
int tagion_wallet_read_wallet(const(WalletT*) wallet_instance,
                            const uint8_t* device_pin_buf, 
                            const size_t device_pin_buf_len, 
                            const uint8_t* recover_generator_buf,
                            const size_t recover_generator_buf_length,
                            const uint8_t* account_buf,
                            const size_t account_buf_len) {
    try {
        if (wallet_instance is null || wallet_instance.magic_byte != MAGIC_WALLET) {
            return ErrorCode.exception;
        }
        ApiWallet* w = cast(ApiWallet*) wallet_instance.wallet;

        immutable _device_buf = device_pin_buf[0..device_pin_buf_len].idup;
        immutable _recover_generator_buf = recover_generator_buf[0..recover_generator_buf_length].idup;
        immutable _account_buf = account_buf[0..account_buf_len].idup;

        DevicePIN pin = DevicePIN(Document(_device_buf));
        RecoverGenerator recover_generator = RecoverGenerator(Document(_recover_generator_buf));
        AccountDetails account_details = AccountDetails(Document(_account_buf));

        w.readWallet(pin, recover_generator, account_details);
    } 
    catch(Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}

/** 
 * Login to a wallet. Note the wallet must already have been read.
 * Params:
 *   wallet_instance = pointer to the wallet instance
 *   pincode = pointer to the pincode
 *   pincode_len = length of the pincode
 * Returns: ErrorCode
 */
int tagion_wallet_login(const(WalletT*) wallet_instance, 
                    const char* pincode,
                    const size_t pincode_len) {

    try {
        if (wallet_instance is null || wallet_instance.magic_byte != MAGIC_WALLET) {
                return ErrorCode.exception;
        }
        ApiWallet* w = cast(ApiWallet*) wallet_instance.wallet;
        auto _pincode = pincode[0..pincode_len];
        const login_success = w.login(_pincode);
        if (!login_success) {
            return ErrorCode.exception;
        }
    } 
    catch(Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}

///
unittest {
    ApiWallet wallet;
    string password = "wowo wowo";
    string pincode = "1234";
    wallet.createWallet(password, pincode);
    auto bill_insert = wallet.forceBill(1000.TGN);

    const device_pin = wallet._pin.toDoc;
    const recover_generator = wallet._wallet.toDoc;
    const account = wallet.account.toDoc;

    WalletT w;
    int rt = tagion_wallet_create_instance(&w);
    assert(rt == ErrorCode.none);

    rt = tagion_wallet_read_wallet(&w, 
                                &device_pin.data[0], 
                                device_pin.data.length,
                                &recover_generator.data[0],
                                recover_generator.data.length,
                                &account.data[0],
                                account.data.length);
    assert(rt == ErrorCode.none);

    ApiWallet* read_wallet = cast(ApiWallet*) w.wallet;
    assert(read_wallet._pin == wallet._pin);
    assert(read_wallet._wallet == wallet._wallet);
    assert(read_wallet.account == wallet.account);

    rt = tagion_wallet_login(&w, &pincode[0], pincode.length);
    assert(rt == ErrorCode.none);
}


enum PUBKEYSIZE = 33; /// Size of a public key

/** 
 * Get the wallets current public key
 * Params:
 *   wallet_instance = pointer to the wallet instance
 *   pubkey = pointer to the returned pubkey
 *   pubkey_len = length of the returned pubkey
 * Returns: 
 */
int tagion_wallet_get_current_pkey(const(WalletT*) wallet_instance,
    uint8_t** pubkey,
    size_t* pubkey_len) {
    try {
        if (wallet_instance is null || wallet_instance.magic_byte != MAGIC_WALLET) {
            return ErrorCode.exception;
        }
        ApiWallet* w = cast(ApiWallet*) wallet_instance.wallet;
        const pkey = w.getCurrentPubkey;

        *pubkey = cast(uint8_t*) &pkey[0];
        *pubkey_len = pkey.length;
    }
    catch (Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}
///
unittest {
    WalletT w;
    int rt = tagion_wallet_create_instance(&w);
    const passphrase = "some passphrase";
    const pincode = "1234";
    rt = tagion_wallet_create_wallet(&w, &passphrase[0], passphrase.length, &pincode[0], pincode.length);

    uint8_t* pubkey_buf;
    size_t pubkey_len;

    rt = tagion_wallet_get_current_pkey(&w, &pubkey_buf, &pubkey_len);
    assert(rt == ErrorCode.none);
    assert(pubkey_len == PUBKEYSIZE);
    const pkey = cast(Pubkey) pubkey_buf[0..pubkey_len].idup;

    rt = tagion_wallet_get_current_pkey(&w, &pubkey_buf, &pubkey_len);
    assert(rt == ErrorCode.none);
    assert(pubkey_len == PUBKEYSIZE);
    const _pkey = cast(Pubkey) pubkey_buf[0..pubkey_len].idup;
    assert(pkey == _pkey, "should not have changed");
}



/** 
 * Create bill from wallet information
 * Params:
 *   amount = the amount for the new bill
 *   pubkey = pointer to the pubkey
 *   pubkey_len = length of the public key
 *   time = timestamp as the number of hnsecs since midnight, January 1st, 1 A.D. for the
        current time.
 *   bill_buf = pointer to the bill buffer that is returned
 *   bill_buf_len = length of the returned bill buffer
 * Returns: ErrorCode
 */
int tagion_wallet_create_bill(const double amount, 
                    const uint8_t* pubkey, 
                    const size_t pubkey_len, 
                    const(int64_t) time,
                    uint8_t** bill_buf,
                    size_t* bill_buf_len) {
    try {
        if (pubkey_len != PUBKEYSIZE) {
            return ErrorCode.exception;
        }
        const _amount = TagionCurrency(amount);
        const _pubkey = cast(Pubkey) pubkey[0..pubkey_len].idup;
        const _time = sdt_t(time);
        const bill = requestBill(_amount, _pubkey, _time);
        const bill_doc = bill.toDoc;
        *bill_buf = cast(uint8_t*) &bill_doc.data[0];
        *bill_buf_len = bill_doc.full_size;
    }
    catch(Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}
///
unittest {
    ApiWallet wallet;
    wallet.createWallet("wowo", "1234");
    const double amount = 213.2f;
    const pkey = wallet.getCurrentPubkey;
    const time = currentTime;

    uint8_t* bill_buf;
    size_t bill_buf_len;
    int rt = tagion_wallet_create_bill(amount, &pkey[0], pkey.length, cast(const(int64_t)) time, &bill_buf, &bill_buf_len);
    assert(rt == ErrorCode.none);

    const read_bill = TagionBill(Document(bill_buf[0..bill_buf_len].idup));
    assert(read_bill.value == TagionCurrency(amount));
    assert(read_bill.time == time);
    assert(read_bill.owner == wallet.getCurrentPubkey);
}

/** 
 * Forces an amount in the wallet. Note. should only be used for testing
 * Params:
 *   wallet_instance = pointer to the wallet instance
 *   amount = the amount to add
 * Returns: ErrorCode
 */
int tagion_wallet_force_bill(const(WalletT*) wallet_instance,
                        const double amount) {
    try {
        if (wallet_instance is null || wallet_instance.magic_byte != MAGIC_WALLET) {
            return ErrorCode.exception;
        }
        ApiWallet* w = cast(ApiWallet*) wallet_instance.wallet;

        const _amount = TagionCurrency(amount);
        w.forceBill(_amount);
    } 
    catch (Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}

/** 
 * Get the AccountDetails
 * Params:
 *   wallet_instance = pointer to the wallet instance
 *   account_buf = pointer to the returned buffer for the account
 *   account_buf_len = length of the returned buffer
 * Returns: ErrorCode
 */
int tagion_wallet_get_account(const(WalletT*) wallet_instance,
    uint8_t** account_buf,
    size_t* account_buf_len) {
    try {
        if (wallet_instance is null || wallet_instance.magic_byte != MAGIC_WALLET) {
            return ErrorCode.exception;
        }
        ApiWallet* w = cast(ApiWallet*) wallet_instance.wallet;

        const account_doc = w.account.toDoc;
        const account_data = account_doc.data;
        *account_buf = cast(uint8_t*) &account_data[0];
        *account_buf_len = account_doc.full_size;
    } 
    catch (Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}

/** 
 * Get the DevicePIN
 * Params:
 *   wallet_instance = pointer to the wallet instance
 *   device_pin_buf = pointer to the returned buffer for the devicepin
 *   device_pin_buf_len = length of the returned buffer
 * Returns: ErrorCode
 */
int tagion_wallet_get_device_pin(const(WalletT*) wallet_instance,
    uint8_t** device_pin_buf,
    size_t* device_pin_buf_len) {
    try {
        if (wallet_instance is null || wallet_instance.magic_byte != MAGIC_WALLET) {
            return ErrorCode.exception;
        }
        ApiWallet* w = cast(ApiWallet*) wallet_instance.wallet;

        const device_pin_doc = w._pin.toDoc;
        const device_pin_data = device_pin_doc.data;
        *device_pin_buf = cast(uint8_t*) &device_pin_data[0];
        *device_pin_buf_len = device_pin_doc.full_size;
    } 
    catch (Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}

/** 
 * Get the recovergenerator
 * Params:
 *   wallet_instance = pointer to the wallet instance
 *   recover_generator_buf = pointer to the returned buffer for the recovergenerator
 *   recover_generator_buf_len = length of the returned buffer
 * Returns: ErrorCode
 */
int tagion_wallet_get_recover_generator(const(WalletT*) wallet_instance,
    uint8_t** recover_generator_buf,
    size_t* recover_generator_buf_len) {
    try {
        if (wallet_instance is null || wallet_instance.magic_byte != MAGIC_WALLET) {
            return ErrorCode.exception;
        }
        ApiWallet* w = cast(ApiWallet*) wallet_instance.wallet;

        const recover_generator_doc = w._wallet.toDoc;
        const recover_generator_data = recover_generator_doc.data;
        *recover_generator_buf = cast(uint8_t*) &recover_generator_data[0];
        *recover_generator_buf_len = recover_generator_doc.full_size;
    } 
    catch (Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}

///
unittest {
    import tagion.wallet.AccountDetails;
    import tagion.hibon.HiBONRecord;
    import tagion.wallet.WalletRecords;
    WalletT w;
    int rt = tagion_wallet_create_instance(&w);
    assert(rt == ErrorCode.none);

    string passphrase = "some_passphrase";
    string pincode = "some_pincode";

    rt = tagion_wallet_create_wallet(&w, &passphrase[0], passphrase.length, &pincode[0], pincode.length);
    assert(rt == ErrorCode.none);

    uint8_t* account_buf;
    size_t account_len;
    rt = tagion_wallet_get_account(&w, &account_buf, &account_len); 
    assert(rt == ErrorCode.none);
    const _account_buf = account_buf[0..account_len].idup;
    const _account_doc = Document(_account_buf);
    assert(_account_doc.isRecord!AccountDetails == true, "doc was not of type AccountDetails");

    uint8_t* device_pin_buf;
    size_t device_pin_len;
    rt = tagion_wallet_get_device_pin(&w, &device_pin_buf, &device_pin_len); 
    assert(rt == ErrorCode.none);
    const _device_pin_buf = device_pin_buf[0..device_pin_len].idup;
    const _device_pin_doc = Document(_device_pin_buf);
    assert(_device_pin_doc.isRecord!DevicePIN == true, "doc was not of type DevicePIN");

    uint8_t* recover_generator_buf;
    size_t recover_generator_len;
    rt = tagion_wallet_get_recover_generator(&w, &recover_generator_buf, &recover_generator_len); 
    assert(rt == ErrorCode.none);
    const _recover_generator_buf = recover_generator_buf[0..recover_generator_len].idup;
    const _recover_generator_doc = Document(_recover_generator_buf);
    assert(_recover_generator_doc.isRecord!RecoverGenerator == true, "doc was not of type RecoverGenerator");
}
    
/** 
 * Pay to a bill
 * Params:
 *   wallet_instance = pointer to the instance of the wallet 
 *   bill_buf = pointer to the tagionbill buffer
 *   bill_buf_len = length of the bill buffer
 *   fees = returned fees
 * Returns: ErrorCode
 */
int tagion_wallet_pay_bill(const(WalletT*) wallet_instance,
    const uint8_t* bill_buf,
    const size_t bill_buf_len,
    double* fees) {
    try {
        if (wallet_instance is null || wallet_instance.magic_byte != MAGIC_WALLET) {
            return ErrorCode.exception;
        }
        ApiWallet* w = cast(ApiWallet*) wallet_instance.wallet;
        const _bill_doc_buf = bill_buf[0..bill_buf_len].idup;  
        const _bill_doc = Document(_bill_doc_buf);
        const doc_error = _bill_doc.valid;
        if (doc_error !is Document.Element.ErrorCode.NONE) {
            return cast(int) doc_error;
        }
        const bill = TagionBill(_bill_doc);

        TagionCurrency returned_fees;
        w.createPayment([bill], returned_fees);
        *fees = returned_fees.value;
    }
    catch (Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}

