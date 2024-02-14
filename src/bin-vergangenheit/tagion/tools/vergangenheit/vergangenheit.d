module tagion.tools.vergangenheit.vergangenheit;
import std.array : join;
import std.getopt;
import std.stdio;
import std.format;
import std.algorithm;
import std.typecons : Yes;
import std.range;
import std.file : exists, tempDir;
import tagion.basic.Types;
import tagion.tools.Basic;
import tagion.tools.revision;
import tagion.crypto.SecureNet;
import tagion.dart.DART;
import tools = tagion.tools.toolsexception;
import tagion.wallet.SecureWallet;
import tagion.tools.wallet.WalletInterface;
import tagion.tools.wallet.WalletOptions;
import tagion.utils.Term;
import tagion.tools.vergangenheit.Rebuild;

mixin Main!(_main);

int _main(string[] args) {
    immutable program = args[0];
    bool version_switch;
    RebuildOptions rebuild_options;
    rebuild_options.path=tempDir;
    GetoptResult main_args;
    try {
        main_args = getopt(args,
                std.getopt.config.caseSensitive,
                std.getopt.config.bundling,
                "version", "display the version", &version_switch,
                "v|verbose", "Prints more debug information", &__verbose_switch, 
                "s|skip-check", "Skip the check of the replicator",        &rebuild_options.skip_check, 
                "P|path", format("Path to store the replicator files (Default %s)", rebuild_options.path), &rebuild_options.path,
        /*
        "c|stdout", "Print to standard output", &standard_output,
                "s|stream", "Parse .hibon file to stdout", &stream_output,
                "o|output", "Output filename only for stdin data", &outputfilename,
                "r|reserved", "Check reserved keys and types enabled", &reserved,
                "p|pretty", format("JSON Pretty print: Default: %s", pretty), &pretty,
                "J", "Input stream format json", &input_json,
                "t|base64", "Convert to base64 output", &output_base64,
                "x|hex", "Convert to hex output", &output_hex,
                "T|text", "Input stream base64 or hex-string", &input_text,
                "sample", "Produce a sample HiBON", &sample,
                "check", "Check the hibon format", &hibon_check,
                "H|hash", "Prints the hash value", &output_hash,
                "D|dartindex", "Prints the DART index", &output_dartindex,
                "ignore", "Ignore document valid check", &ignore,
    */

        

        );
        if (version_switch) {
            revision_text.writeln;
            return 0;
        }

        if (main_args.helpWanted) {
            //            writeln(logo);
            defaultGetoptPrinter(
                    [
                    "Documentation: https://tagion.org/",
                    "",
                    "Usage:",
                    format("%s [<option>...] <in-file>", program),
                    "",
                    "Where:",
                    "<in-file>           Is an input file in .json or .hibon format",
                    "",

                    "<option>:",

                    ].join("\n"),
                    main_args.options);
            return 0;
        }
        const net = new StdSecureNet;
        auto dart_list = args.filter!(file => file.hasExtension(FileExtension.dart));
        tools.check(!dart_list.empty, format("Missing %s file", FileExtension.dart));
        auto db_src = new DART(net, dart_list.front, Yes.read_only);

        dart_list.popFront;
        tools.check(!dart_list.empty, "DART destination file missing");
        auto db_dst = new DART(net, dart_list.front);
        scope (exit) {
            db_src.close;
            db_dst.close;
        }

        WalletOptions[] all_options;
        auto wallet_config_files = args.filter!(file => file.hasExtension(FileExtension.json));
        foreach (file; wallet_config_files) {
            verbose("file %s", file);
            tools.check(file.exists, format("Wallet file %s not found", file));
            WalletOptions wallet_options;
            wallet_options.load(file);
            all_options ~= wallet_options;
        }

        WalletInterface[] wallet_interfaces;

        foreach (wallet_option; all_options) {
            auto wallet_interface = WalletInterface(wallet_option);
            wallet_interface.load;
            wallet_interfaces ~= wallet_interface;
        }
        if (!wallet_interfaces.empty) {
            import tagion.tools.secretinput;

            auto wallets = wallet_interfaces[];
            info("Press ctrl-C to break");
            //info("Press ctrl-D to skip the wallet");
            info("Press ctrl-A to show the pincode");
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

        auto recorder_list = args.filter!(file => file.hasExtension(FileExtension.hibon)).array;
        writefln("recorder_list=%s", recorder_list);
        auto rebuild = Rebuild(rebuild_options, db_src, db_dst, recorder_list);
        //rebuild.recorder_list = args.filter!(file => file.hasExtension(FileExtension.hibon)).array;

        rebuild.sortReplicator(net);
        verbose("%-(%s\n%)", rebuild.replicator_files);
        rebuild.prepareReplicator(net);
    }
    catch (Exception e) {
        error(e);

        return 1;
    }
    return 0;
}
