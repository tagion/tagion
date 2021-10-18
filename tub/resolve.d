module tub.resolve;

import std.stdio;
import std.file;
import std.getopt;
import std.format;
import std.array;
import std.path : buildPath;
import std.json;

int resolve(string dir_tub, string dir_src, string unit) {
    string dir_unit() {
        return format!"%s-%s"("lib", unit);
    }

    string absolute_path_unit() {
        return buildPath(dir_src, dir_unit);
    }

    string absolute_path_unit_json() {
        return buildPath(dir_src, dir_unit, "unit.json");
    }

    auto unit_json = parseJSON(readText(absolute_path_unit_json));
    auto unit_deps_lib = unit_json["dependencies"]["lib"]; // TODO: Make safe

    writefln("%s", unit_deps_lib);

    return 0;
}

int main(string[] args) {
    string dir_tub;
    string dir_src;
    string unit;

    auto main_args = getopt(args,
            std.getopt.config.caseSensitive,
            std.getopt.config.bundling,
            "dirtub|t", "Sets the Tub directory", &dir_tub,
            "dirsrc|s", "Sets the source directory", &dir_src,
            "unit|u", "Sets the source directory", &unit
    );

    if (main_args.helpWanted) {
        defaultGetoptPrinter(
                [
                "This program must run using 'make resolve-<target>'.",
                "",
                "<option>:",
                ]
                .join("\n"), main_args.options
        );

        return 0;
    }

    return resolve(dir_tub, dir_src, unit);
}
