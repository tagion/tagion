module tagion.tools.tprofview;

import std.getopt;
import std.stdio;
import std.file : exists;
import std.format;
import std.range;
import std.algorithm;
import std.typecons;
import std.conv : to;
import std.traits;

import tagion.tools.revision;

import tagion.tools.Basic;

mixin Main!(_main);

struct ProfLine {
    uint num_calls;
    uint tree_time;
    uint func_time;
    string func_name;
    string toString() const {
        return format("%8d   %8d   %8d   %8.3f    %s", num_calls, tree_time, func_time,
                double(func_time) / double(num_calls),
                func_name);
    }

}

enum ProfSort {
    calls,
    tree,
    func,
}

struct ProfInfo {
    string[] head;
    ProfLine[] proflines;
    void display(ProfSort sort_option)(const uint num) const {
        scope list_sort = proflines.dup
            .sort!((a, b) => a.tupleof[sort_option] > b.tupleof[sort_option]);
        head.each!writeln;
        list_sort
            .take(num)
            .each!writeln;
    }

    void display(const ProfSort sort_option, const uint num) const {
    SortOption:
        final switch (sort_option) {
            static foreach (E; EnumMembers!ProfSort) {
        case E:
                display!E(num);
                break SortOption;
            }
        }
    }
}

ProfInfo loadProf(ref File fin) {
    ProfInfo result;
    auto prof_file = fin.byLine;
    prof_file
        .find!(l => l.startsWith("========")); //, "==")); //, "======"));
    result.head = prof_file.take(4).map!(l => l.idup).array;
    //.find!(l => (l.length > 0) && (l[0]=='=')); //, "======"));
    result.proflines = prof_file
        .map!(l => tuple(
                l.split.take(3).map!(n => n.to!uint).array,
                l.split.drop(4).join(" ")))
        .filter!(prof => prof[1].length > 0)
        .map!(prof => ProfLine(prof[0][0], prof[0][1], prof[0][2], prof[1].idup))
        .array;
    return result;
}

int _main(string[] args) {
    immutable program = args[0];

    bool version_switch;
    uint number_tobe_listed = 10;
    string trace_file = "trace.log";
    ProfSort prof_sort = ProfSort.tree;
    auto main_args = getopt(args,
            std.getopt.config.caseSensitive,
            std.getopt.config.bundling,
            "version", "display the version", &version_switch,
            "l", format("Number to be listed (default %d)", number_tobe_listed), &number_tobe_listed,
            "s", format("Sort flag %s (default %s)", [EnumMembers!ProfSort], prof_sort), &prof_sort,
    );

    if (version_switch) {
        revision_text.writeln;
        return 0;
    }

    if (main_args.helpWanted) {
        defaultGetoptPrinter(
                [
                revision_text,
                "Documentation: https://tagion.org/",
                "",
                "Usage:",
                format("%s [<option>...] <trace-file> ", program),
                "",
                "<option>:",

                ].join("\n"),
                main_args.options);
        return 0;
    }
    if (args.length > 1) {
        trace_file = args[1];
        writefln("trace file %s", trace_file);
    }
    try {
        auto fin = File(trace_file, "r");
        scope (exit) {
            fin.close;
        }
        const prof_list = loadProf(fin);
        prof_list.display(prof_sort, number_tobe_listed);
    }
    catch (Exception e) {
        stderr.writeln(e.msg);
        return 1;
    }
    return 0;
}
