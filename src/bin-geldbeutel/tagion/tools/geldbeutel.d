module tagion.tools.geldbeutel;

import tagion.tools.revision;
import tagion.tools.Basic;

mixin Main!(_main, "newwallet");

import tagion.crypto.SecureNet;

//import Wallet=tagion.wallet.SecureWallet;

int _main(string[] args) {
    immutable program = args[0];
    auto config_file = "wallet.json";
    return 0;
}
