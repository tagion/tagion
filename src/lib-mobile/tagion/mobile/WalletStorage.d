module tagion.mobile.WalletStorage;

import tagion.wallet.WalletRecords : RecoverGenerator, DevicePIN, AccountDetails;
import tagion.hibon.HiBONRecord : fwrite;
import tagion.wallet.SecureWallet;
import tagion.hibon.Document;
import tagion.crypto.SecureNet : StdSecureNet, BadSecureNet;
import std.file : fread = read, exists, remove;
import tagion.hibon.HiBON;
import tagion.crypto.Cipher;

class WalletStorage {

    protected const char[] _walletDataPath;

    this(const char[] walletDataPath) {
        _walletDataPath = walletDataPath;
    }

    bool isWalletExist() {
        return exists(_walletDataPath);
    }

    bool write(const(SecureWallet!(StdSecureNet)) secure_wallet) {
        // Create a hibon for wallet data.
        auto storedHibon = new HiBON();
        storedHibon["pin"] = secure_wallet.pin.toHiBON;
        storedHibon["account"] = secure_wallet.account.toHiBON;
        storedHibon["wallet"] = secure_wallet.wallet.toHiBON;

        try {
            // Write to the file
            _walletDataPath.fwrite(storedHibon);
            return 1;
        }
        catch (Exception e) {
            return 0;
        }
    }

    bool read(SecureWallet!(StdSecureNet) secure_wallet) {
        if (exists(_walletDataPath)) {
            immutable walletFile = cast(immutable(ubyte)[]) fread(_walletDataPath);
            // TODO: add decryption for a file content.
            // Wallet data in HiBON format.
            auto storedHibon = Document(walletFile);
            auto devicePin = storedHibon["pin"].get!Document;
            auto account = storedHibon["account"].get!Document;
            auto wallet = storedHibon["wallet"].get!Document;

            secure_wallet = SecureWallet!(StdSecureNet)(DevicePIN(devicePin),
                RecoverGenerator(wallet), AccountDetails(account));
            return 1;
        }
        return 0;
    }

    bool remove() {
        if (exists(_walletDataPath)) {
            try {
                _walletDataPath.remove();
                return 1;
            }
            catch (Exception e) {
                return 0;
            }
        }
        return 0;
    }
}
