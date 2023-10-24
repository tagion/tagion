module tagion.tools.wallet.WalletOptions;

import tagion.utils.JSONCommon;
import tagion.basic.Types : FileExtension;
import std.path;
import tagion.wallet.KeyRecover : standard_questions;
import tagion.services.options;

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

    string[] questions;

    string contract_address;
    string dart_address;
    string dart_shell_address;
    string contract_shell_address;
    string faucet;
    /**
    * @brief set default values for wallet
    */
    void setDefault() nothrow {
        accountfile = "account".setExtension(FileExtension.hibon);
        walletfile = "wallet".setExtension(FileExtension.hibon);
        quizfile = "quiz".setExtension(FileExtension.hibon);
        contractfile = "contract".setExtension(FileExtension.hibon);
        billsfile = "bills".setExtension(FileExtension.hibon);
        paymentrequestsfile = "paymentrequests".setExtension(FileExtension.hibon);
        devicefile = "device".setExtension(FileExtension.hibon);
        addr = "http://localhost:8080";
        questions = standard_questions.dup;
        contract_address = contract_sock_addr("Node_0_" ~ "CONTRACT_");
        dart_address = contract_sock_addr("Node_0_" ~ "DART_");
        dart_shell_address = "/api/v1/dart";
        contract_shell_address = "/api/v1/contract";
        faucet = "/api/v1/invoice2pay";

        port = 10800;
    }

    mixin JSONCommon;
    mixin JSONConfig;
}
