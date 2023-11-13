module tagion.tools.tprofview;

import std.algorithm;
import std.conv : to;
import std.exception : assumeWontThrow;
import std.file : exists;
import std.format;
import std.getopt;
import std.range;
import std.stdio;
import std.traits;
import std.typecons;
import std.utf;
import tagion.tools.Basic;
import tagion.tools.revision;

mixin Main!(_main);

struct ProfLine {
    uint num_calls;
    uint tree_time;
    uint func_time;
    double per_calls;
    string func_name;
    this(const uint num_calls, const uint tree_time, const uint func_time, string func_name) pure @nogc {
        this.num_calls = num_calls;
        this.tree_time = tree_time;
        this.func_time = func_time;
        per_calls = double(tree_time) / double(num_calls);
        this.func_name = func_name;
    }

    string toString() const {
        return format("%8d   %8d   %8d   %8.3f    %s", num_calls, tree_time, func_time,
                per_calls,
                func_name);
    }

}

enum ProfSort {
    calls,
    tree,
    func,
    percalls,
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

ProfInfo loadProf(ref File fin, const bool verbose) {
    ProfInfo result;
    bool validUTF(Line)(Line line) nothrow {
        try {
            line.value.validate;
        }
        catch (Exception e) {
            if (verbose) {
                assumeWontThrow({ writeln(e.msg); writefln("%d:%s", line.index, line.value); }());
            }
            return false;
        }
        return true;
    }

    auto prof_file = fin.byLine // .map!(l => l.filter!(c => c.isValidDchar))
        .enumerate(1)
        .filter!(l => validUTF(l))
        .map!(l => l.value.toUTF8);
    prof_file
        .find!(l => l.startsWith("========")); //, "==")); //, "======"));
    result.head = prof_file.take(4).map!(l => l.idup).array;
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
    bool verbose_switch;
    auto main_args = getopt(args,
            std.getopt.config.caseSensitive,
            std.getopt.config.bundling,
            "version", "display the version", &version_switch,
            "l", format("Number to be listed (default %d)", number_tobe_listed), &number_tobe_listed,
            "s", format("Sort flag %s (default %s)", [EnumMembers!ProfSort], prof_sort), &prof_sort,
    "v|verbose", "verbose switch", &verbose_switch,
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
        const prof_list = loadProf(fin, verbose_switch);
        prof_list.display(prof_sort, number_tobe_listed);
    }
    catch (Exception e) {
        stderr.writeln(e.msg);
        return 1;
    }
    return 0;
}
