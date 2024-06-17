/// API for using a wallet
module tagion.api.wallet;
import tagion.api.errors;
import tagion.api.basic;
import tagion.api.hibon;
import tagion.wallet.Wallet;
import tagion.crypto.SecureNet;
import core.stdc.stdint;
import tagion.hibon.Document;
import tagion.script.TagionCurrency;
import tagion.utils.StdTime;
import tagion.crypto.Types : Pubkey;
import tagion.script.common : TagionBill, SignedContract;
import tagion.crypto.random.random;
import std.string : representation;

import tagion.wallet.WalletRecords : DevicePIN, RecoverGenerator;
import tagion.wallet.AccountDetails;

import tagion.crypto.SecureNet;

extern (C):
version(unittest) {

} else {
nothrow:
}

/// Pointer to securenet
struct securenet_t {
    int magic_byte = MAGIC.SECURENET;
    void* securenet;
}

/**
  Generate a keypair used from a password / menmonic
  The function does **NOT** validate the menmonic and 
  should therefore be validated by another function.

  The function may be used in a minimal fashion without 
  DevicePIN and salt. If null arguments are supplied for the pin,
  then no DevicePIN is returned. 
  Likewise if null is supplied for the salt then the salt will not
  be used.

 
  Params:
    passphrase_ptr = Pointer to passphrase
    passphrase_len = Length of the passphrase
    salt_ptr = Optional salt for the menmonic phrase
    salt_len = Length of the optional salt
    out_securenet = The allocated securenet used for cryptographic operations
    pin_ptr = Pointer to the pin
    pin_len = Length of the pin
    out_device_doc_ptr = Returned device doc ptr
    out_device_doc_len = Length of the returned device doc
  Returns: 
    [tagion.api.errors.ErrorCode]
 */
int tagion_generate_keypair (
    const(char)* passphrase_ptr,
    const(size_t) passphrase_len,
    const(char)* salt_ptr,
    const(size_t) salt_len,
    securenet_t* out_securenet,
    const(char*) pin_ptr,
    const(size_t) pin_len,
    uint8_t** out_device_doc_ptr,
    size_t* out_device_doc_len,
) {


    try {
        if (out_securenet.magic_byte != MAGIC.SECURENET) {
            return ErrorCode.error; // TODO: better message
        }
        const _passphrase = passphrase_ptr[0..passphrase_len];
        const _salt = salt_ptr[0..salt_len];

        SecureNet _net = new StdSecureNet;

        if (pin_ptr !is null) {
            DevicePIN _pin;
            const _pincode = pin_ptr[0..pin_len];

            void set_pincode(
                scope const(ubyte[]) R,
                scope const(char[]) pincode) scope
            in (_net !is null)
            do {
                auto seed = new ubyte[_net.hashSize];
                getRandom(seed);
                _pin.setPin(_net, R, pincode.representation, seed.idup);
            }

            ubyte[] R;
            enum size_of_privkey = 32;
            scope(exit) {
                set_pincode(R, _pincode);
                R[] = 0;
                auto device_doc = _pin.toDoc.serialize;
                *out_device_doc_ptr = cast(uint8_t*) &device_doc[0];
                *out_device_doc_len = device_doc.length;
            }
            _net.generateKeyPair(_passphrase, _salt,
                    (scope const(ubyte[]) data) { R = data[0 .. size_of_privkey].dup; });


        } else {
            _net.generateKeyPair(_passphrase, _salt); 
        }

        out_securenet.securenet = cast(void*) _net;
    } catch(Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}

unittest {
    /// Create minimal key-pair
    {
        securenet_t my_keypair;
        string my_mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon";

        int error_code = tagion_generate_keypair(&my_mnemonic[0], my_mnemonic.length, null, 0, &my_keypair, null, 0, null, null);
        assert(error_code == ErrorCode.none);
    }
    /// Create key-pair with salt 
    {
        securenet_t my_keypair;
        string my_mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon";
        string salt = "somesalt";

        int error_code = tagion_generate_keypair(&my_mnemonic[0], my_mnemonic.length, &salt[0], salt.length, &my_keypair, null, 0, null, null);
        assert(error_code == ErrorCode.none);
    }
}

/** 
 * Decrypt and create a securenet from a devicepin and pincode
   Params:
     pin_ptr = Pointer to the pincode
     pin_len = Length of the pincode
     devicepin_ptr = Pointer to the device pin document
     devicepin_len = Length of the device pin document
     out_securenet = The allocated securenet
   Returns: 
     [tagion.api.errors.ErrorCode]
 */
int tagion_decrypt_devicepin (
    const(char*) pin_ptr,
    const(size_t) pin_len,
    uint8_t* devicepin_ptr,
    size_t devicepin_len,
    securenet_t* out_securenet,
) {
    try {
        if (out_securenet.magic_byte != MAGIC.SECURENET) {
            return ErrorCode.error; // TODO: better message
        }
        const _pincode = pin_ptr[0..pin_len];
        const _device_doc_buf = cast(immutable) devicepin_ptr[0..devicepin_len];

        DevicePIN _pin = DevicePIN(Document(_device_doc_buf));

        SecureNet _net = new StdSecureNet;
        auto R = new ubyte[_net.hashSize];
        scope (exit) {
            R[] = 0;
        }

        const recovered = _pin.recover(_net, R, _pincode.representation);
        if (!recovered) {
            return ErrorCode.exception; // TODO: better error message
        }
        _net.createKeyPair(R);

        out_securenet.securenet = cast(void*) _net;
    } catch(Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}

/// Decrypt a devicepin
unittest {
    /// create key-pair with devicepin
    import tagion.hibon.HiBONRecord;
    import std.format;
    securenet_t my_keypair;
    string my_mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon";
    string pincode = "1234";

    uint8_t* device_buf;
    size_t device_len;
    int error_code = tagion_generate_keypair(&my_mnemonic[0], my_mnemonic.length, null, 0, &my_keypair, &pincode[0], pincode.length, &device_buf, &device_len);
    assert(error_code == ErrorCode.none);

    const _device_buf = device_buf[0..device_len].idup;
    const device_doc = Document(_device_buf);
    assert(device_doc.isRecord!DevicePIN, format("the doc was not of type %s", DevicePIN.stringof));

    /// decrypt the devicepin
    securenet_t other_securenet;
    error_code = tagion_decrypt_devicepin(&pincode[0], pincode.length, device_buf, device_len, &other_securenet);
    assert(error_code == ErrorCode.none);

    /// try to login with wrong pin
    string wrong_pincode = "4321";
    securenet_t false_securenet;

    error_code = tagion_decrypt_devicepin(&wrong_pincode[0], wrong_pincode.length, device_buf, device_len, &false_securenet);
    assert(error_code == ErrorCode.exception, "should give exception with wrong pin");
    assert(false_securenet.securenet is null, "should not have created a securenet");
}


/// Sign a message
int tagion_sign_message (
    const(securenet_t) root_net,
    const(uint8_t*) message_ptr,
    const size_t message_len,
    uint8_t** signature_ptr, 
    size_t* signature_len,
) {
    assert(0, "TODO");
}

/// Create a signed contract
int tagion_create_signed_contract(
    const(SecureNet) root_net, 
    const(TagionBill[]) to_pay,
    const(TagionBill[]) available,
    const(ubyte[][]) derivers,
    const(Pubkey) change,
    TagionBill[] used,
    SignedContract* produced_contract
) {
    assert(0, "TODO");
}

version(none):

alias ApiWallet = Wallet!StdSecureNet;

enum MAGIC_WALLET = 0xA000_0001;

/// Wallet Type
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
        wallet_instance.magic_byte = MAGIC_WALLET;
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
int tagion_wallet_create_wallet(
        const(WalletT*) wallet_instance, 
        const char* passphrase, 
        const size_t passphrase_len,
        const char* pincode,
        const size_t pincode_len
) {
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
int tagion_wallet_read_wallet(
        const(WalletT*) wallet_instance,
        const uint8_t* device_pin_buf, 
        const size_t device_pin_buf_len, 
        const uint8_t* recover_generator_buf,
        const size_t recover_generator_buf_length,
        const uint8_t* account_buf,
        const size_t account_buf_len
) {
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
int tagion_wallet_get_current_pkey(
    const(WalletT*) wallet_instance,
    uint8_t** pubkey,
    size_t* pubkey_len
) {
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

        const _account_buf = w.account.toDoc.serialize;
        *account_buf = cast(uint8_t*) &_account_buf[0];
        *account_buf_len = _account_buf.length;
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

        const _device_pin_buf = w._pin.toDoc.serialize;
        *device_pin_buf = cast(uint8_t*) &_device_pin_buf[0];
        *device_pin_buf_len = _device_pin_buf.length;
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

        const _recover_generator_buf = w._wallet.toDoc.serialize;
        *recover_generator_buf = cast(uint8_t*) &_recover_generator_buf[0];
        *recover_generator_buf_len = _recover_generator_buf.length;
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


/** 
 * Make TRT request (serialized, ready to send)
 * Params:
 *   wallet_instance = pointer to the instance of the wallet 
 *   doc_buf = pointer to the request document buffer
 *   doc_buf_len = length of the request document buffer
 * Returns: ErrorCode
 */
int tagion_wallet_make_trtread(const(WalletT*) wallet_instance,
    uint8_t** doc_buf,
    size_t* doc_buf_len) {
    try {
        if (wallet_instance is null || wallet_instance.magic_byte != MAGIC_WALLET) {
            return ErrorCode.exception;
        }
        ApiWallet* w = cast(ApiWallet*) wallet_instance.wallet;
        const sender = w.readIndicesByPubkey();
        const trtread_doc = cast(ubyte[])sender.toDoc.serialize;
        *doc_buf = cast(uint8_t*) &trtread_doc[0];
        *doc_buf_len = trtread_doc.length;
    }
    catch (Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}


