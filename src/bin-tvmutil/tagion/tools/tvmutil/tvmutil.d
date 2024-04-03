module tagion.tools.tvmutil.tvmutil;
import std.getopt;
import std.format;
import std.stdio;
import std.array;
import tagion.tools.Basic;
import tagion.tools.revision;

mixin Main!(_main);

int _main(string[] args) {
    immutable program = args[0];
    bool version_switch;
    GetoptResult main_args;
    try {

        main_args = getopt(args, std.getopt.config.caseSensitive,
                std.getopt.config.bundling,
                "version", "display the version", &version_switch,
                "v|verbose", "Enable verbose print-out", &__verbose_switch,/*
                "dry", "Dry-run this will not save the wallet", &__dry_switch,
                "C|create", "Create the wallet an set the confidence", &confidence,
                "l|list", "List wallet content", &list,
                "s|sum", "Sum of the wallet", &sum,
                "amount", "Create an payment request in tagion", &amount, //"path", "File path", &path,
                "update", "Update wallet", &update,
                "response", "Response from update (response.hibon)", &response_name,
                "force", "Force input bill", &force,
                "migrate", "Migrate from old account to dart-index account", &migrate,
*/
                
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
                    format("%s [<option>...] file.wasm [file.hibon ...] ", program),
                    "",

                    "<option>:",

                    ].join("\n"),
                    main_args.options);
            return 0;
        }
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
