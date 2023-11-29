module tagion.tools.auszahlung.auszahlung;
import core.thread;
import std.algorithm;
import std.array;
import std.file : exists, mkdir, mkdirRecurse, setAttributes;
import std.format;
import std.getopt;
import std.path;
import std.range;
import std.stdio;
import std.typecons;
import std.conv : to, octal;
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
import tagion.crypto.Types;
import tagion.wallet.SecureWallet;
import tagion.hibon.BigNumber;
import tagion.hibon.HiBONtoText;
import tagion.script.common;
import tagion.crypto.random.random;
import tagion.utils.StdTime;
import tagion.communication.HiRPC;
import std.csv;
import std.string : representation;

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

enum file_protect=octal!444;
enum MIN_WALLETS = 3;
int _main(string[] args) {
    import tagion.wallet.SecureWallet : check;

    immutable program = args[0];
    bool version_switch;
    bool list;
    bool sum;
    bool force;
    bool update;
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
                "update", "Update wallet", &update,
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
            return 0;
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
            scope(success) {
            common_wallet_interface.save(false);
            }
            check(wallet_interfaces.all!(wiface => wiface.secure_wallet.isLoggedin),
                    "All wallets must be loggedin to add amount");
            const amount_tgn = TagionCurrency(amount);
            const bill = common_wallet_interface.secure_wallet.requestBill(amount_tgn);
            string bill_path = buildPath(path, "bills");
            mkdirRecurse(bill_path);
            const filename = buildPath(bill_path, format("bill_%s", common_wallet_interface.secure_wallet.account.name))
                .setExtension(FileExtension.hibon);
            filename.fwrite(bill);
                scope(success) {
                    filename.setAttributes(file_protect);
                }
            return 0;
        }
        if (force) {
            scope(success) {
            common_wallet_interface.save(false);
            }
            check(wallet_interfaces.all!(wiface => wiface.secure_wallet.isLoggedin),
                    "All wallets must be loggedin to force the bill");
            foreach (arg; args[1 .. $].filter!(file => file.hasExtension(FileExtension.hibon))) {
                const bill = arg.fread!TagionBill;
                with (common_wallet_interface) {
                    good("%s", toText(hash_net, bill));
                    verbose("%s", show(bill));
                    const added = secure_wallet.addBill(bill);
                    check(added, "Bill was not found");
                }
            }
            common_wallet_interface.listAccount(stdout, hash_net);
            common_wallet_interface.listInvoices(stdout);

            return 0;
        }
        auto csv_files = args[1 .. $].filter!(file => file.hasExtension(FileExtension.csv));
        const contracts = buildPath(path, "contracts");
        if (!csv_files.empty) {
            mkdirRecurse(contracts);
        }
        foreach (filename; csv_files) {
            scope(success) {
            common_wallet_interface.save(false);
            }
            verbose("CVS %s", filename);
            auto fin = File(filename, "r");
            scope (exit) {
                fin.close;
            }
            enum pubkey_name = "PUBKey";
            enum amount_name = "Amount";
            TagionBill[] to_pay;
            TagionCurrency total_amount;
            foreach (record; csvReader!(string[string])(fin.byLine.joiner("\n"), null, ';')) {
                const pubkey = Pubkey(format("@%s", record[pubkey_name]).decode);
                const amount_tgn = record[amount_name].to!double.TGN;
                total_amount += amount_tgn;
                auto nonce = new ubyte[4];
                getRandom(nonce);
                to_pay ~= TagionBill(amount_tgn, currentTime, pubkey, nonce.idup);
                //writefln("pubkey %s amount %s", record[pubkey_name], record[amount_name]);

                //writefln("%s", bills[$-1].toPretty);
            }
            SignedContract signed_contract;
            TagionCurrency fees;
            with (common_wallet_interface) {
                secure_wallet.createPayment(to_pay, signed_contract, fees);
                const contract_filename = buildPath(contracts, baseName(filename)).setExtension(FileExtension.hibon);
                const message = secure_wallet.net.calcHash(signed_contract);
                const contract_net = secure_wallet.net.derive(message);
                const hirpc = HiRPC(contract_net);
                const hirpc_submit = hirpc.submit(signed_contract);
                verbose("submit\n%s", show(hirpc_submit));
                secure_wallet.account.hirpcs ~= hirpc_submit.toDoc;
                contract_filename.fwrite(hirpc_submit);
                scope(success) {
                    contract_filename.setAttributes(file_protect);
                }
            }
            good("Total %sTGN", total_amount);

        }
        if (update) {
            verbose("Update");
           with (common_wallet_interface) {
            const message=secure_wallet.net.calcHash(WalletInterface.update_tag.representation);
                const update_net= secure_wallet.net.derive(message);
                const hirpc=HiRPC(update_net);
                const req=secure_wallet.getRequestCheckWallet(hirpc);
                const update_req=buildPath(path, update_tag).setExtension(FileExtension.hibon);
                update_req.fwrite(req);
                scope(success) {
                    update_req.setAttributes(file_protect);
                }
            }
        }
    }
    catch (Exception e) {
        error("%s", e.msg);
        verbose("%s", e.toString);
        return 1;
    }
    return 0;
}
