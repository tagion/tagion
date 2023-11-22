module tagion.tools.auszahlung.auszahlung;
import core.thread;
import std.algorithm;
import std.array;
import std.file : exists, mkdir;
import std.format;
import std.getopt;
import std.path;
import std.range;
import std.stdio;
import std.typecons;
import tagion.basic.Message;
import tagion.basic.Types : FileExtension, hasExtension;
import tagion.basic.tagionexceptions;
import tagion.hibon.Document;
import tagion.hibon.HiBONFile : fread, fwrite;
import tagion.network.ReceiveBuffer;
import tagion.script.TagionCurrency;
import tagion.tools.Basic;
import tagion.tools.revision;
import tagion.tools.wallet.WalletInterface;
import tagion.tools.wallet.WalletOptions;
import tagion.utils.Term;
import tagion.utils.Term;
import tagion.wallet.AccountDetails;
import tagion.wallet.KeyRecover;
import tagion.wallet.SecureWallet;
import tagion.wallet.WalletRecords;
import tagion.wallet.BIP39;
import tagion.basic.Types : encodeBase64;
import tagion.basic.range : eatOne;
mixin Main!(_main, "payout");

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
    import tagion.wallet.SecureWallet : check;
    
    immutable program = args[0];
    bool version_switch;
    /*
    bool overwrite_switch; /// Overwrite the config file
    bool create_account;
    bool change_pin;
    bool set_default_quiz;

    string output_filename;
    string derive_code;
    string path;
    string pincode;
    uint bip39;
    bool wallet_ui;
    bool info;
    bool pubkey_info;
    string _passphrase;
    string _salt;
    char[] passphrase;
    char[] salt;
    string account_name;
    scope (exit) {
        passphrase[]=0;
        salt[]=0;
    }
*/
    GetoptResult main_args;
    WalletOptions options;
    WalletInterface[] wallet_interfaces;
    WalletInterface.Switch wallet_switch;
    auto config_files = args
        .filter!(file => file.hasExtension(FileExtension.json));
    auto config_file=default_wallet_config_filename;
    if (!config_files.empty) {
        config_file=config_files.eatOne;
    }
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
                "dry", "Dry-run this will not save the wallet", &__dry_switch,
        /*
        "pay", "Creates a payment contract", &wallet_switch.pay,
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
                "send", "Send a contract to the shell", &wallet_switch.send, //"answers", "Answers for wallet creation", &answers_str,
                "sendkernel", "Send a contract to the kernel", &wallet_switch.sendkernel, //"answers", "Answers for wallet creation", &answers_str,
                "P|passphrase", "Set the wallet passphrase", &_passphrase,
                "create-invoice", "Create invoice by format LABEL:PRICE. Example: Foreign_invoice:1000", &wallet_switch
                    .invoice, 
                "x|pin", "Pincode", &pincode,
                "amount", "Create an payment request in tagion", &wallet_switch.amount,
                "force", "Force input bill", &wallet_switch.force,
                "dry", "Dry-run this will not save the wallet", &__dry_switch,
                "req", "List all requested bills", &wallet_switch.request,
                "update", "Request a wallet updated", &wallet_switch.update,
                "trt-update", "Request a update on all derivers", &wallet_switch.trt_update,
                
                "address", format(
                    "Sets the address default: %s", options.contract_address), &options
                    .addr,
                "faucet", "request money from the faucet", &wallet_switch.faucet,
                    // "dart-addr", format("Sets the dart address default: %s", options.dart_address), &options.dart_address,
                "bip39", "Generate bip39 set the number of words", &bip39,
                "name", "Sets the account name", &account_name,
                "info", "Prints the public key and the name of the account", &info,
                "pubkey", "Prints the public key", &pubkey_info,
*/
        );
    }
    catch (GetOptException e) {
        error(e.msg);
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
                format("%s [<option>...] <wallet.json> ... ", program),
                "",

                "<option>:",

                ].join("\n"),
                main_args.options);
        return 0;
    }
    try {
    WalletOptions[] all_options;
        foreach(file; config_files) {
            verbose("file %s", file);
            check(file.hasExtension(FileExtension.json), format("%s is not a %s file", file, FileExtension.json));
            check(file.exists, format("File %s not found", file));
            WalletOptions wallet_options;
            wallet_options.load(file);
        all_options~=wallet_options;
        }
        verbose("Number of wallets %d", all_options.length);
        
        foreach(wallet_option; all_options) {
            auto wallet_interface=WalletInterface(wallet_option);
            wallet_interface.load;
            wallet_interfaces~=wallet_interface;
        }
        foreach(wallet_interface; wallet_interfaces) {
            writefln("Name %s", wallet_interface.secure_wallet.account.name);
        }
        /*
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
                .countUntil!(file => file.tasExtension(FileExtension.json) && !file.exists);
            config_file = (new_config_file < 0) ? config_file : args[new_config_file];
            options.save(config_file);
            if (overwrite_switch) {
                return 0;
            }
        }
        auto wallet_interface = WalletInterface(options);
        if (bip39 > 0) {
            import tagion.wallet.bip39_english : words;

            const number_of_words = [12, 24];
            check(number_of_words.canFind(bip39), format("Invalid number of word %d should be (%(%d, %))", bip39, number_of_words));
            const wordlist = WordList(words);
            passphrase = wordlist.passphrase(bip39);

            printf("%.*s\n", cast(int) passphrase.length, &passphrase[0]); 
        }
        else {
            (() @trusted { passphrase = cast(char[]) _passphrase; }());
        }
        if (!_salt.empty) {
            auto salt_tmp = (() @trusted => cast(char[]) _salt)();
            scope (exit) {
                salt_tmp[]=0;
            }
            salt ~= WordList.presalt ~ _salt;
        }
        if (!passphrase.empty) {
            check(!pincode.empty, "Missing pincode");
            wallet_interface.generateSeedFromPassphrase(passphrase, pincode);
            wallet_interface.save(false);
            return 0;
        }
        if (!wallet_interface.load) {
            create_account = true;
            writefln("Wallet dont't exists");
            WalletInterface.pressKey;
        }
        bool info_only;
        if (info) {
            if (wallet_interface.secure_wallet.account.name.empty) {
            writefln("%sAccount name has not been set (use --name)%s", YELLOW, RESET);
                return 0;
            }
            writefln("%s,%s", 
            wallet_interface.secure_wallet.account.name, 
            wallet_interface.secure_wallet.account.owner.encodeBase64);
            info_only=true;
        }
        if (pubkey_info) {
            if (wallet_interface.secure_wallet.account.owner.empty) {
            writefln("%sAccount pubkey has not been set (use --name)%s", YELLOW, RESET);
                return 0;
            }
             writefln("%s", 
            wallet_interface.secure_wallet.account.owner.encodeBase64);
             info_only=true;
        }
        if (info_only) {
            return 0;
        }
        change_pin = change_pin && !pincode.empty;

        if (create_account) {
            wallet_interface.generateSeed(wallet_interface.quiz.questions, false);
            return 0;
        }
        else if (change_pin) {
            wallet_interface.loginPincode(Yes.ChangePin);
            return 0;
        }

        if (wallet_interface.secure_wallet !is WalletInterface.StdSecureWallet.init) {
            if (!pincode.empty) {
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
                return 4;
            }
        }
        if (!account_name.empty) {
            wallet_interface.secure_wallet.account.name=account_name;
            wallet_interface.secure_wallet.account.owner=wallet_interface.secure_wallet.net.pubkey;
            wallet_switch.save_wallet=true;
            
        }
        wallet_interface.operate(wallet_switch, args);
        */
    }
    catch (Exception e) {
        error("%s",  e.msg);
        verbose("%s", e.toString);
        return 1;
    }
    return 0;
}
