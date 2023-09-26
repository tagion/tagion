module tagion.tools.wallet.geldbeutel;
import core.thread;
import std.format;
import std.getopt;
import std.stdio;
import std.array;
import std.path;
import std.file : exists, mkdir;
import tagion.hibon.HiBONRecord : fwrite, fread;
import std.algorithm;
import std.range;
import tagion.tools.revision;
import tagion.tools.Basic;
import tagion.basic.Types : hasExtension, FileExtension;
import tagion.wallet.KeyRecover;
import tagion.utils.Term;
import tagion.wallet.SecureWallet;
import tagion.wallet.WalletRecords;
import tagion.wallet.AccountDetails;
import tagion.basic.Message;
import tagion.hibon.Document;
import tagion.basic.tagionexceptions;
import tagion.tools.wallet.WalletOptions;
import tagion.tools.wallet.WalletInterface;
import tagion.script.TagionCurrency;
import tagion.utils.Term;
import std.typecons;
import tagion.network.ReceiveBuffer;

mixin Main!(_main, "newwallet");

import tagion.crypto.SecureNet;

import Wallet = tagion.wallet.SecureWallet;

/**
 * @brief build file path if needed file with folder long path
 * @param file - input/output parameter with filename
 * @param path - forlders destination to file
 */
@safe
static void set_path(ref string file, string path) {
    file = buildPath(path, file.baseName);
}

int _main(string[] args) {
    immutable program = args[0];
    bool version_switch;
    bool overwrite_switch; /// Overwrite the config file
    bool create_account;
    bool change_pin;
    bool set_default_quiz;

    string output_filename;
    string derive_code;
    string path;
    string pincode;
    bool wallet_ui;
    GetoptResult main_args;
    WalletOptions options;
    WalletInterface.Switch wallet_switch;
    const user_config_file = args
        .countUntil!(file => file.hasExtension(FileExtension.json) && file.exists);
    auto config_file = (user_config_file < 0) ? "wallet.json" : args[user_config_file];
    if (config_file.exists) {
        options.load(config_file);
    }
    else {
        options.setDefault;
    }

    try {
        main_args = getopt(args, std.getopt.config.caseSensitive,
                std.getopt.config.bundling,
                "version", "display the version", &version_switch,
                "v|verbose", "Enable verbose print-out", &__verbose_switch,
                "O|overwrite", "Overwrite the config file and exits", &overwrite_switch,
                "path", format("Set the path for the wallet files : default %s", path), &path,
                "wallet", format("Wallet file : default %s", options.walletfile), &options.walletfile,
                "device", format("Device file : default %s", options.devicefile), &options.devicefile,
                "quiz", format("Quiz file : default %s", options.quizfile), &options.quizfile,
                "C|create", "Create a new account", &create_account,
                "c|changepin", "Change pin-code", &change_pin,
                "o|output", "Output filename", &wallet_switch.output_filename,
                "l|list", "List wallet content", &wallet_switch.list, //"questions", "Questions for wallet creation", &questions_str,
                "s|sum", "Sum of the wallet", &wallet_switch.sum, //"questions", "Questions for wallet creation", &questions_str,
                "send", "Send a contract to the network", &wallet_switch.send,//"answers", "Answers for wallet creation", &answers_str,
                /*
                "path", format("Set the path for the wallet files : default %s", path), &path,
                "wallet", format("Wallet file : default %s", options.walletfile), &options.walletfile,
                "device", format("Device file : default %s", options.devicefile), &options.devicefile,
                "quiz", format("Quiz file : default %s", options.quizfile), &options.quizfile,
                "invoice|i", format("Invoice file : default %s", invoicefile), &invoicefile,
                "create-invoice|c", "Create invoice by format LABEL:PRICE. Example: Foreign_invoice:1000", &create_invoice_command,
                "contract|t", format("Contractfile : default %s", options.contractfile), &options.contractfile,
                "amount", "Display the wallet amount", &print_amount,
                "pay|I", format("Invoice to be payed : default %s", payfile), &payfile,
                "update|U", "Update your wallet", &update_wallet,
                "item|m", "Invoice item select from the invoice file", &item,
                */
                "pin|x", "Pincode", &pincode,
                "amount", "Create an payment request in tagion", &wallet_switch.amount,
                "force", "Force input bill", &wallet_switch.force,
                "pay", "Creates a payment contract", &wallet_switch.pay,
                "dry", "Dry-run this will not save the wallet", &__dry_switch,
                "req", "List all requested bills", &wallet_switch.request,
                "update", "Request a wallet updated", &wallet_switch.update, /*
                "port|p", format("Tagion network port : default %d", options.port), &options.port,
                "url|u", format("Tagion url : default %s", options.addr), &options.addr,
                "visual|g", "Visual user interface", &wallet_ui,
                "questions", "Questions for wallet creation", &questions_str,
                "answers", "Answers for wallet creation", &answers_str,
                "generate-wallet", "Create a new wallet", &generate_wallet,
                "health", "Healthcheck the node", &check_health,
                "unlock", "Remove lock from all local bills", &unlock_bills,
                "nossl", "Disable ssl encryption", &none_ssl_socket,
    */

        

        );
    }
    catch (GetOptException e) {
        stderr.writeln(e.msg);
        return 1;
    }
    if (version_switch) {
        revision_text.writeln;
        return 0;
    }
    if (main_args.helpWanted) {
        //            writeln(logo);
        defaultGetoptPrinter(
                [
            // format("%s version %s", program, REVNO),
            "Documentation: https://tagion.org/",
            "",
            "Usage:",
            format("%s [<option>...] <config.json> <files>", program),
            "",

            "<option>:",

        ].join("\n"),
                main_args.options);
        return 0;
    }
    try {
        verbose("Config file %s", config_file);
        const new_config = (!config_file.exists || overwrite_switch);
        if (path) {
            if (!new_config) {
                writefln("To change the path you need to use the overwrite switch -O");
                return 10;
            }
            options.walletfile.set_path(path);
            options.quizfile.set_path(path);
            options.devicefile.set_path(path);
            options.accountfile.set_path(path);
            options.billsfile.set_path(path);
            options.paymentrequestsfile.set_path(path);
            const dir = options.walletfile.dirName;
            if (!dir.exists) {
                dir.mkdir;
            }
        }
        if (new_config) {
            const new_config_file = args
                .countUntil!(file => file.hasExtension(FileExtension.json) && !file.exists);
            config_file = (new_config_file < 0) ? config_file : args[new_config_file];
            options.save(config_file);
            if (overwrite_switch) {
                return 0;
            }
        }
        auto wallet_interface = WalletInterface(options);
        if (!wallet_interface.load) {
            create_account = true;
            writefln("Wallet dont't exists");
            WalletInterface.pressKey;
            //wallet_interface.quiz.questions = standard_questions.dup;
        }
        change_pin = change_pin && !pincode.empty;
        if (create_account) {
            wallet_interface.generateSeed(wallet_interface.quiz.questions, false);
            return 0;
        }
        else if (change_pin) {
            //if (wallet_interface.loginPincode) {
            wallet_interface.loginPincode(Yes.ChangePin);
            //                wallet_interface.changePin;
            //}
            return 0;
        }

        if (wallet_interface.secure_wallet !is WalletInterface.StdSecureWallet.init) {
            if (!pincode.empty) {
                writefln("Login:%s", pincode);
                const flag = wallet_interface.secure_wallet.login(pincode);

                if (!flag) {
                    stderr.writefln("%sWrong pincode%s", RED, RESET);
                    return 3;
                }
                verbose("%1$sLoggedin%2$s", GREEN, RESET);
            }
            else if (!wallet_interface.loginPincode(No.ChangePin)) {
                wallet_ui = true;
                writefln("%1$sWallet not loggedin%2$s", YELLOW, RESET);
                //WalletInterface.pressKey;

                return 4;
            }
        }
        wallet_interface.operate(wallet_switch, args);
    }
    catch (Exception e) {
        writefln("%1$sError: %3$s%2$s", RED, RESET, e.msg);
        verbose("%s", e.toString);
        return 1;
    }
    return 0;
}
