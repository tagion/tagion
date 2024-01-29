module tagion.tools.wallet.geldbeutel;
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
import std.exception : ifThrown;
import core.stdc.stdio : printf;
import tagion.basic.Message;
import tagion.basic.Types : FileExtension, hasExtension;
import tagion.basic.tagionexceptions;
import tagion.hibon.Document;
import tagion.hibon.HiBONFile : fread, fwrite;
import tagion.hibon.HiBONRecord : isHiBONRecord;
import tagion.communication.HiRPC;
import tagion.network.ReceiveBuffer;
import tagion.script.TagionCurrency;
import tagion.tools.Basic;
import tagion.tools.revision;
import tagion.tools.wallet.WalletInterface;
import tagion.tools.wallet.WalletOptions;
import tagion.utils.Term;
import tagion.wallet.AccountDetails;
import tagion.wallet.KeyRecover;
import tagion.wallet.SecureWallet;
import tagion.wallet.WalletRecords;
import tagion.wallet.BIP39;
import tagion.basic.Types : encodeBase64;
import tagion.hibon.HiBONException;

mixin Main!(_main, "wallet");

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
    bool overwrite_switch; /// Overwrite the config file
    bool create_account;
    bool change_pin;

    string path;
    string pincode;
    uint bip39;
    bool bip39_recover;
    bool wallet_ui;
    bool show_info;
    bool pubkey_info;
    bool list;
    bool sum;
    bool history;
    string _passphrase;
    string _salt;
    char[] passphrase;
    char[] salt;
    string account_name;
    scope (exit) {
        passphrase[] = 0;
        salt[] = 0;
    }
    GetoptResult main_args;
    WalletOptions options;
    WalletInterface.Switch wallet_switch;
    const user_config_file = args
        .countUntil!(file => file.hasExtension(FileExtension.json) && file.exists);
    auto config_file = (user_config_file < 0) ? default_wallet_config_filename : args[user_config_file];
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
                "l|list", "List wallet content", &list,
                "s|sum", "Sum of the wallet", &sum,
                "send", "Send a contract to the shell", &wallet_switch.send,
                "sendkernel", "Send a contract to the kernel", &wallet_switch.sendkernel,
                "P|passphrase", "Set the wallet passphrase", &_passphrase,
                "create-invoice", "Create invoice by format LABEL:PRICE. Example: Foreign_invoice:1000", &wallet_switch
                .invoice,
                "x|pin", "Pincode", &pincode,
                "amount", "Create an payment request in tagion", &wallet_switch.amount,
                "force", "Force input bill", &wallet_switch.force,
                "pay", "Creates a payment contract", &wallet_switch.pay,
                "dry", "Dry-run this will not save the wallet", &__dry_switch,
                "req", "List all requested bills", &wallet_switch.request,
                "update", "Request a wallet updated", &wallet_switch.update,
                "trt-update", "Request a update on all derivers", &wallet_switch.trt_update,
                "trt-read", "TEMPOARY: send trt pubkey read request", &wallet_switch.trt_read,
                "history", "Request print the transaction history", &history,

                "address", format(
                "Sets the address default: %s", options.contract_address),
                &options.addr,
                "faucet", "request money from the faucet", &wallet_switch.faucet,
                "bip39", "Generate bip39 set the number of words", &bip39,
                "recover", "Recover bip39 from word list", &bip39_recover,
                "name", "Sets the account name", &account_name,
                "info", "Prints the public key and the name of the account", &show_info,
                "pubkey", "Prints the public key", &pubkey_info,

        );
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
        if (!_salt.empty) {
            auto salt_tmp = (() @trusted => cast(char[]) _salt)();
            scope (exit) {
                salt_tmp[] = 0;
            }
            salt ~= BIP39.presalt ~ _salt;
        }
        if (bip39 > 0 || bip39_recover) {
            wallet_interface.load;
            import std.uni;
            import tagion.tools.secretinput;
            import tagion.wallet.bip39_english : words;

            if (bip39_recover) {
                auto line = stdin.readln().dup;
                toLowerInPlace(line);
                auto word_list = line.split;
                passphrase = word_list.join(" ");
                bip39 = cast(uint) word_list.length;
            }
            const number_of_words = [12, 24];
            check(number_of_words.canFind(bip39), format("Invalid number of word %d should be (%(%d, %))", bip39, number_of_words));
            char[] pincode_1;
            char[] pincode_2;
            scope (exit) {
                pincode_1[] = 0;
                pincode_2[] = 0;
            }

            if (!dry_switch) {
                info("Press ctrl-C to break");
                info("Press ctrl-A to show the pincode");
                while (pincode_1.length == 0) {
                    const keycode = getSecret("Pincode: ", pincode_1);
                    if (keycode == KeyStroke.KeyCode.CTRL_C) {
                        error("Wallet has not been created");
                        return 1;
                    }
                }
                info("Repeat the pincode");
                for (;;) {
                    const keycode = getSecret("Pincode: ", pincode_2);
                    if (keycode == KeyStroke.KeyCode.CTRL_C) {
                        error("Wallet has not been created");
                        return 1;
                    }
                    if (pincode_1 == pincode_2) {
                        break;
                    }
                    error("Pincode did not match");
                }
                good("Pin-codes matches");
            }
            if (!bip39_recover) {
                const wordlist = BIP39(words);
                passphrase = wordlist.passphrase(bip39);

                good("This is the recovery words");
                printf("%.*s\n", cast(int) passphrase.length, &passphrase[0]);
                good("Write them down");
            }
            const recovered = wallet_interface.generateSeedFromPassphrase(passphrase, pincode_1, _salt);
            check(recovered, "Wallet was not recovered");
            good("Wallet was recovered");
            if (!dry_switch) {
                wallet_interface.save(false);
            }
            return 0;
        }
        else {
            (() @trusted { passphrase = cast(char[]) _passphrase; }());
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
        if (show_info) {
            if (wallet_interface.secure_wallet.account.name.empty) {
                writefln("%sAccount name has not been set (use --name)%s", YELLOW, RESET);
                return 0;
            }
            writefln("%s,%s",
                    wallet_interface.secure_wallet.account.name,
                    wallet_interface.secure_wallet.account.owner.encodeBase64);
            info_only = true;
        }
        if (pubkey_info) {
            if (wallet_interface.secure_wallet.account.owner.empty) {
                warn("Account pubkey has not been set (use --name)");
                return 0;
            }
            writefln("%s",
                    wallet_interface.secure_wallet.account.owner.encodeBase64);
            info_only = true;
        }
        if (list) {
            const hash_net = new StdHashNet;
            wallet_interface.listAccount(vout, hash_net);
            wallet_interface.listInvoices(vout);
            sum = true;
        }
        if (history) {
            import std.range;
            import std.datetime;
            import tagion.utils.StdTime;
            import std.conv;

            auto hist = wallet_interface.secure_wallet.account.reverse_history();
            const now = Clock.currTime();
            const today = now.to!Date;
            const yesterday = today - 1.days;

            // The date of the previous bill
            Date prev_day;

            foreach (item; hist) {
                const bill_time = SysTime(cast(long) item.bill.time);
                const bill_day = bill_time.to!Date;
                void print_date() {

                    if (bill_day == prev_day) {
                        return;
                    }

                    if (bill_day == today) {
                        writeln("Today:");
                    }
                    else if (bill_day == yesterday) {
                        writeln("Yesterday:");
                    }
                    else if (bill_day.month == today.month && bill_day.year == today.year) {
                        writeln("This Month:");
                    }
                    else if (bill_day.month == today.month - 1 && bill_day.year == today.year) {
                        writeln("Last Month:");
                    }
                    else if (bill_day.year == today.year) {
                        writeln("This Year:");
                    }
                    else if (bill_day.year == today.year - 1) {
                        writeln("Last Year:");
                    }
                }

                print_date();
                prev_day = bill_day;

                final switch (item.type) {
                case HistoryItemType.receive:
                    writefln("(%s) %s%8s%s\n", item.balance, GREEN, item.bill.value, RESET);
                    break;
                case HistoryItemType.send:
                    const BALANCE_COLOR = (item.status is ContractStatus.succeeded) ? RED : YELLOW;
                    writefln("(%s) %s%8s%s (fee: %s) to %s\n", item.balance, BALANCE_COLOR, item.bill.value, RESET, item
                            .fee, item.bill
                            .owner.encodeBase64);
                    break;
                }
            }
            info_only = true;
        }

        if (sum) {
            wallet_interface.sumAccount(vout);
            info_only = true;
        }
        if (info_only) {
            return 0;
        }

        if (create_account) {
            wallet_interface.generateSeed(wallet_interface.quiz.questions, false);
            return 0;
        }
        else if (change_pin) {
            wallet_interface.loginPincode(changepin : true);
            check(wallet_interface.secure_wallet.isLoggedin, "Failed to login");
            good("Pincode correct");
            return 0;
        }

        if (wallet_interface.secure_wallet !is WalletInterface.StdSecureWallet.init) {
            if (!pincode.empty) {
                const flag = wallet_interface.secure_wallet.login(pincode);

                if (!flag) {
                    error("Wrong pincode");
                    return 3;
                }
                good("Loggedin");
            }
            else if (!wallet_interface.loginPincode(changepin : false)) {
                wallet_ui = true;
                warn("Wallet not loggedin");
                return 4;
            }
        }
        foreach (file; args.filter!(file => file.hasExtension(FileExtension.hibon))) {
            check(file.exists, format("File %s not found", file));

            const hirpc_response = file.fread!(HiRPC.Receiver)
                .ifThrown!HiBONException(HiRPC.Receiver.init);
            if (hirpc_response is HiRPC.Receiver.init) {
                continue;
            }
            writefln("File %s %s", file, hirpc_response.toPretty);
            const ok = wallet_interface.secure_wallet.setResponseUpdateWallet(hirpc_response)
                .ifThrown!HiBONException(
                        wallet_interface.secure_wallet.setResponseCheckRead(hirpc_response)
            );

            check(ok, format("HiPRC %s is not a valid response", file));
            wallet_switch.save_wallet = true;
        }
        if (!account_name.empty) {
            wallet_interface.secure_wallet.account.name = account_name;
            wallet_interface.secure_wallet.account.owner = wallet_interface.secure_wallet.net.pubkey;
            wallet_switch.save_wallet = true;

        }

        wallet_interface.operate(wallet_switch, args);
    }
    catch (GetOptException e) {
        error(e.msg);
        return 1;
    }
    catch (Exception e) {
        error(e);
        return 1;
    }
    return 0;
}
