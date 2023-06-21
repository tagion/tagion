module tagion.utils.getopt;

import std.getopt;
import std.typecons;
import std.process : environment;
import std.path;

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

// template Example(Args...) {
//     Example = Tuple!("%s " ~ args[0], program_name, args[1..$]);
// }

struct XDG {
    private string xdg_home_dir(string XDG_SPEC, string fallback) {
        const home = environment.get("HOME");
        const res = environment.get(XDG_SPEC, buildPath(home, fallback));
        assert(res.isValidPath);
        assert(res.isRooted);
        return res;
    }

    string data_home() {
        return xdg_home_dir("XDG_DATA_HOME", ".local/share");
    }

    string config_home() {
        return xdg_home_dir("XDG_CONFIG_HOME", ".config");
    }

    string cache_home() {
        return xdg_home_dir("XDG_CACHE_HOME", ".local/cache");
    }
}
