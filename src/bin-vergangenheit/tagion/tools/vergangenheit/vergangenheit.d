@description("Rebuild dart database from replicator files Carsten edition") 
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
    rebuild_options.path = tempDir;
    GetoptResult main_args;
    try {
        main_args = getopt(args,
                std.getopt.config.caseSensitive,
                std.getopt.config.bundling,
                "version", "display the version", &version_switch,
                "v|verbose", "Prints more debug information", &__verbose_switch,
                "s|skip-check", "Skip the check of the replicator", &rebuild_options.skip_check,
                "P|path", format(
                "Path to store the replicator files (Default %s)", rebuild_options.path), &rebuild_options.path,
        );
        if (version_switch) {
            revision_text.writeln;
            return 0;
        }

        if (main_args.helpWanted) {
            defaultGetoptPrinter(
                    [
                "Documentation: https://docs.tagion.org/",
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
        const net = new StdHashNet;
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

        auto recorder_list = args.filter!(file => file.hasExtension(FileExtension.hibon)).array;
        writefln("recorder_list=%s", recorder_list);
        auto rebuild = Rebuild(rebuild_options, db_src, db_dst, recorder_list);

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
