module tagion.utils.getopt;

import std.getopt;
import tagion.tools.revision;

immutable logo = import("logo.txt");

/// Wrapper for defaultGetoptPrinter that prints the logo and documentation link
void tagionGetoptPrinter(string text, Option[] opt) @safe {
    import std.stdio : stdout;
    import std.format.write : formattedWrite;

    // stdout global __gshared is trusted with a locked text writer
    auto w = (() @trusted => stdout.lockingTextWriter())();

    w.formattedWrite("%s\n", logo);
    w.formattedWrite("Documentation: https://docs.tagion.org/\n");

    defaultGetoptFormatter(w, text, opt);
}
