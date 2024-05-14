module tagion.api.wallet;
import tagion.api.errors;
import tagion.api.hibon;
import tagion.wallet.Wallet;
import tagion.crypto.SecureNet;
import core.stdc.stdint;
import tagion.hibon.Document;
import tagion.script.TagionCurrency;

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

unittest {
    WalletT w;
    int rt = tagion_wallet_create_instance(&w);
    assert(rt == ErrorCode.none);
}

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

enum PUBKEYSIZE = 33;
int tagion_wallet_create_bill(const double amount, 
                    const uint8_t* pubkey, 
                    const size_t pubkey_len, 
                    const(int64_t) time) {
    try {
        if (pubkey_len != 33) {
            return ErrorCode.exception;
        }
        const _amount = TagionCurrency(amount);
        const _pubkey = cast(Pubkey) pubkey[0..pubkey_len].idup;
        const _time = sdt_t(time);

        const bill = requestBill(_amount, _pubkey, _time);
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
    auto bill_insert = wallet.addBill(1000.TGN);

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




