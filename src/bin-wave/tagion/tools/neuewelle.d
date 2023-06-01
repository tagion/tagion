module tagion.tools.neuewelle;

// import std.stdio;
import std.format;
import std.getopt;
import tagion.tools.Basic;
import tagion.utils.getopt;

mixin Main!(_main);

int _main(string[] args) {

    bool version_switch;
    immutable program = args[0];

    auto main_args = getopt(args,
        "v|version", "Print revision information", &version_switch
    );

    if (main_args.helpWanted) {
        tagionGetoptPrinter(
            format("%s", program),
            main_args.options
        );
        return 0;
    }

    return 0;
}
