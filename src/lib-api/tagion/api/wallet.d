module tagion.api.wallet;
import tagion.api.errors;
import tagion.api.hibon;
import tagion.wallet.Wallet;
import tagion.crypto.SecureNet;

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



unittest {
    WalletT w;
    int rt = tagion_wallet_create_instance(&w);
    assert(rt == ErrorCode.none);

    string passphrase = "some_passphrase";
    string pincode = "some_pincode";

    rt = tagion_wallet_create_wallet(&w, &passphrase[0], passphrase.length, &pincode[0], pincode.length);
    assert(rt == ErrorCode.none);
}
