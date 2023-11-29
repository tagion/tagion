module tagion.tools.auszahlung.auszahlung;
import core.thread;
import std.algorithm;
import std.array;
import std.file : exists, mkdir, mkdirRecurse;
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
import tagion.basic.Types : encodeBase64, Buffer;
import tagion.basic.range : eatOne;
import tagion.basic.basic : isinit;
import tagion.crypto.SecureNet;
import tagion.wallet.SecureWallet;
import tagion.hibon.BigNumber;
import tagion.script.common;

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

enum MIN_WALLETS = 3;
int _main(string[] args) {
    import tagion.wallet.SecureWallet : check;

    immutable program = args[0];
    bool version_switch;
    bool list;
    bool sum;
    bool force;
    string path;
    uint confidence;
    double amount;
    GetoptResult main_args;
    WalletOptions options;
    WalletInterface[] wallet_interfaces;
    auto config_files = args
        .filter!(file => file.hasExtension(FileExtension.json));
    auto config_file = default_wallet_config_filename;
    if (!config_files.empty) {
        config_file = config_files.eatOne;
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
                "C|create", "Create the wallet an set the confidence", &confidence,
                "l|list", "List wallet content", &list,
                "s|sum", "Sum of the wallet", &sum,
                "amount", "Create an payment request in tagion", &amount,
                "path", "File path", &path,
                "force", "Force input bill", &force,

        

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
        const(HashNet) hash_net = new StdHashNet;
        WalletOptions[] all_options;
        auto common_wallet_interface = WalletInterface(options);
        common_wallet_interface.load;
        if (list) {
            common_wallet_interface.listAccount(stdout, hash_net);
            common_wallet_interface.listInvoices(stdout);
            sum = true;
        }
        if (sum) {
            common_wallet_interface.sumAccount(stdout);
        }
        verbose("amount %s", amount);
        if (config_files.empty) {
            return 0;
        }
        foreach (file; config_files) {
            verbose("file %s", file);
            check(file.hasExtension(FileExtension.json), format("%s is not a %s file", file, FileExtension.json));
            check(file.exists, format("File %s not found", file));
            WalletOptions wallet_options;
            wallet_options.load(file);
            all_options ~= wallet_options;
        }
        verbose("Number of wallets %d", all_options.length);

        foreach (wallet_option; all_options) {
            auto wallet_interface = WalletInterface(wallet_option);
            wallet_interface.load;
            wallet_interfaces ~= wallet_interface;
        }
        import tagion.tools.secretinput;

        info("Press ctrl-C to break");
        info("Press ctrl-D to skip the wallet");
        info("Press ctrl-A to show the pincode");
        {
            auto wallets = wallet_interfaces[];
            while (!wallets.empty) {

                writefln("Name %s", wallets.front.secure_wallet.account.name);
                char[] pincode;
                scope (exit) {
                    pincode[] = 0;
                }
                const keycode = getSecret("Pincode: ", pincode);
                with (KeyStroke.KeyCode) {
                    switch (keycode) {
                    case CTRL_C:
                        error("Break the wallet login");
                        return 1;
                    case CTRL_D:
                        warn("Skip %s", wallets.front.secure_wallet.account.name);
                        wallets.popFront;
                        continue;
                    default:
                        if (wallets.front.secure_wallet.login(pincode)) {
                            good("Pincode correct");
                            wallets.popFront;
                        }
                        else {
                            error("Incorrect pincode");
                        }
                    }
                }
            }
        }
        if (!confidence.isinit) {
            check(common_wallet_interface.secure_wallet.wallet.isinit,
                    "Common wallet has already been created");
            check(wallet_interfaces.length >= MIN_WALLETS, format("More than %d wallets needed", MIN_WALLETS));
            check(wallet_interfaces.all!(wallet => wallet.secure_wallet.isLoggedin),
                    "The pincode of some of the wallet is not correct");
            check(confidence <= wallet_interfaces.length, format(
                    "Confidence can not be greater than number of wallets %d", wallet_interfaces.length));
            verbose("Confidence is %d", confidence);
            Buffer[] answers;
            foreach (ref wallet; wallet_interfaces) {
                ubyte[] privkey;
                scope (exit) {
                    privkey[] = 0;
                }
                const __net = cast(StdSecureNet)(wallet.secure_wallet.net);
                __net.__expose(privkey);
                answers ~= hash_net.rawCalcHash(privkey);
            }
            auto key_recover = KeyRecover(hash_net);
            key_recover.createKey(answers, confidence);
            common_wallet_interface.secure_wallet =
                WalletInterface.StdSecureWallet(DevicePIN.init, key_recover.generator);
            common_wallet_interface.secure_wallet.recover(answers);

            verbose("Write wallet %s", common_wallet_interface.secure_wallet.isLoggedin);
            options.questions = null;

            common_wallet_interface.save(true);
            options.save(config_file);
            return 0;
        }
        {
            common_wallet_interface.load;
            confidence = common_wallet_interface.secure_wallet.wallet.confidence;
            const number_of_loggins = wallet_interfaces
                .count!((wallet_iface) => wallet_iface.secure_wallet.isLoggedin);
            verbose("Loggedin %d", number_of_loggins);
            check(confidence <= number_of_loggins, format("At least %d wallet need to open the transaction", confidence));

            Buffer[] answers;
            foreach (wallet; wallet_interfaces) {
                ubyte[] privkey;
                scope (exit) {
                    privkey[] = 0;
                }
                const __net = cast(StdSecureNet)(wallet.secure_wallet.net);
                if (__net) {
                    __net.__expose(privkey);
                }
                answers ~= hash_net.rawCalcHash(privkey);
            }
            common_wallet_interface.secure_wallet.recover(answers);
            check(common_wallet_interface.secure_wallet.isLoggedin, "Wallet could not be activated");
            good("Wallet activated");
        }

        if (amount > 0) {
            BigNumber total = BigNumber(cast(ulong) amount);
            total *= TagionCurrency.BASE_UNIT;
            const MAX_TGN = (TagionCurrency.UNIT_MAX / TagionCurrency.BASE_UNIT).TGN;
            writefln("Total %s", total);
            writefln("Rest  %s", total % TagionCurrency.UNIT_MAX);
            writefln("Store %s", total / TagionCurrency.UNIT_MAX);
            const whole_bills = cast(uint)(total / TagionCurrency.UNIT_MAX);
            //BigNumber paid;
            TagionBill[] bills;
            foreach (i; iota(whole_bills)) {
                bills ~= common_wallet_interface.secure_wallet.requestBill(MAX_TGN);
            }
            const rest = (cast(long)((total % TagionCurrency.UNIT_MAX) / TagionCurrency.BASE_UNIT)).TGN;
            writefln("rest %s", rest);
            bills ~= common_wallet_interface.secure_wallet.requestBill(rest);
            bills.each!((bill) => writefln("%s", bill.toPretty));
            string bill_path = buildPath(path, "bills");
            mkdirRecurse(bill_path);
            foreach (i, bill; bills) {
                const filename = buildPath(bill_path, format("bill_%02d", i)).setExtension(FileExtension.hibon);
                filename.fwrite(bill);
            }
            //writefln("account %s", common_wallet_interface.secure_wallet.account.toPretty);
        }
        if (force) {
            foreach(arg; args[1..$].filter!(file => file.hasExtension(FileExtension.hibon))) {
               const bill=arg.fread!TagionBill;
                //writefln("%s", toText(bill));
               // verbose("%s", show(bill));
               // secure_wallet.addBill(bill);
            }
        }
                common_wallet_interface.save(false);
        // writefln("pin '%s' %d", pincode, pincode.length);
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
        error("%s", e.msg);
        verbose("%s", e.toString);
        return 1;
    }
    return 0;
}
