module tagion.tools.wallet.WalletOptions;

import tagion.utils.JSONCommon;
import tagion.basic.Types : FileExtension;
import std.path;

/**
*
 * struct WalletOptions
 * Struct wallet options files and network status storage models
 */
struct WalletOptions {
    /** account file name/path */
    string accountfile;
    /** wallet file name/path */
    string walletfile;
    /** questions file name/path */
    string quizfile;
    /** device file name/path */
    string devicefile;
    /** contract file name/path */
    string contractfile;
    /** bills file name/path */
    string billsfile;
    /** payments request file name/path */
    string paymentrequestsfile;
    /** address part of network socket */
    string addr;
    /** port part of network socket */
    ushort port;

    /**
    * @brief set default values for wallet
    */
    void setDefault() pure nothrow {
        accountfile = "account".setExtension(FileExtension.hibon);
        walletfile = "wallet".setExtension(FileExtension.hibon);
        quizfile = "quiz".setExtension(FileExtension.hibon);
        contractfile = "contract".setExtension(FileExtension.hibon);
        billsfile = "bills".setExtension(FileExtension.hibon);
        paymentrequestsfile = "paymentrequests".setExtension(FileExtension.hibon);
        devicefile = "device".setExtension(FileExtension.hibon);
        addr = "localhost";
        port = 10800;
    }

    mixin JSONCommon;
    mixin JSONConfig;
}
