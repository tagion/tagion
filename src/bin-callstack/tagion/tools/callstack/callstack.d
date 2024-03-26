module tagion.tools.callstack.callstack;
import std.algorithm : each, map;
import std.array : array, join;
import std.conv;
import std.demangle;
import std.digest : toHexString;
import std.file : exists;
import std.format;
import std.getopt;
import std.json;
import std.path : setExtension;
import std.process : Config, execute;
import std.range : chain;
import std.regex;
import std.stdio;
import std.string : lineSplitter;
import std.uni : isWhite;
import tagion.tools.Basic;
void call_stack_dump(string exefile, string stacktrace) {
    @safe static class Symbol {
        immutable(string) filename;
        immutable(string) mangle;
        ulong addr;
        this(string filename, string mangle) {
            this.mangle = mangle;
            this.filename = filename;
        }
    }

    struct Code {
        const(Symbol) symbol;
        ulong offset;
        ulong mem_addr;
    }

    alias Symbols = Symbol[const(char[])];
    //    scope const(Code)[] backtrace;
    Symbols symbols;
    enum hex = 16;
    const(Code[]) get_backtrace(string stacktrace) {
        Code[] backtrace;
        enum file_symbol = regex(`^([^\(]+)\(([^\)\+]+)?(?:\+0x([^\)]+))?\)\s+\[0x([0-9a-f]+)`);
        scope file = File(stacktrace); // Open for reading
        //  uint call_level;
        void add_symbol(const(char[]) str) @safe {
            auto m = str.matchFirst(file_symbol);

            auto mangle = m[2].idup;
            //          auto s=new Symbol(m[1].idup, m[2].idup, m[3].idup, m[4].idup, call_level);
            if (mangle.length) {
                auto file = m[1].idup;
                const s = symbols.require(mangle, new Symbol(file, mangle));
                ulong offset;
                if (m[3].length) {
                    offset = m[3].to!ulong(hex);
                }
                backtrace ~= const(Code)(s, offset, m[4].to!ulong(hex));
            }
        }

        file.byLine().each!(add_symbol);
        return backtrace;
    }

    const backtrace = get_backtrace(stacktrace);

    //    scope code_sym=new Code[symbols.length];
    void obj_linedump(const(char[]) line) {
        if (line.length) {
            enum whiteregex = regex(`\s+`);
            scope line_split = line.split(whiteregex);
            if (line_split.length >= 7) {
                const mangle = line_split[6];
                auto symbol = symbols.get(mangle, null);
                if (symbol) {
                    symbol.addr = line_split[0].to!ulong(hex);
                }
            }
        }
    }

    execute([
            "objdump",
            "-T",
            exefile,
            ],
            null, Config.init, uint.max)
        .output
        .lineSplitter
        .each!obj_linedump;

    writeln("Call stack");
    enum notfound = "??:?";

    static void code_write(const(Code) code) {
        writefln("- %s %s", code.symbol.filename, code.symbol.mangle);
    }

    foreach (code; backtrace) {
        if (code.symbol.addr == code.symbol.addr.init) {
            code_write(code);
        }
        else {
            static ulong actual_addr(const(Code) code) {
                return code.symbol.addr + code.offset;
            }

            scope addr2line_log = execute([
                    "addr2line",
                    "-e",
                    code.symbol.filename,
                    actual_addr(code).to!string(hex)
                    ],
                    null, Config.init, uint.max);
            if (addr2line_log.output[0 .. notfound.length] == notfound) {
                code_write(code);
            }
            else {
                writef("%s", addr2line_log.output);
            }
        }
        writefln("\t%s\n", demangle(code.symbol.mangle));
    }
}

mixin Main!_main;

enum backtrace_ext = "callstack";

int _main(string[] args) {
    immutable program = args[0];
    bool version_switch;
    string exefile;
    string call_stack_file;
    auto main_args = getopt(args,
            std.getopt.config.caseSensitive,
            std.getopt.config.bundling,
            "version", "display the version", &version_switch, //        "gitlog:g", format("Git log file %s", git_log_json_file), &git_log_json_file,
            "trace|t", "Name of callstack file", &call_stack_file, //        "date|d", format("Recorde the date in the checkout default %s", set_date), &set_date

            

    );

    void help() {
        enum default_program = "tagionwave";
        defaultGetoptPrinter(
                [
            //            format("%s version %s", program, REVNO),
            "Documentation: https://docs.tagion.org/",
            "",
            "Usage:",
            format("%s <exe-file> [-t <backtrace-file>]", program),
        ].join("\n"),
        main_args.options);
        writefln([
            "",
            "Ex.",
            format("%s %s -t %s",
                    program,
                    default_program,
                    "backtrace".setExtension(backtrace_ext)),
            "or",
            format("%s %s # the default backtrace '%s'",
                    program,
                    default_program,
                    default_program.setExtension(backtrace_ext)),
        ].join("\n"));

    }

    if (main_args.helpWanted) {
        help;
        return 0;
    }

    if (args.length <= 1) {
        help;
        return 1;
    }

    exefile = args[1];

    if (exefile.length is 0) {
        help;
        writeln("ERROR: Exe file missing");
        return 1;
    }

    if (!exefile.exists) {
        help;
        writefln("ERROR: Exe file '%s' not found", exefile);
        return 2;
    }

    if (call_stack_file.length is 0) {
        call_stack_file = exefile.setExtension(backtrace_ext);
    }

    if (!call_stack_file.exists) {
        help;
        writefln("ERROR: Call stack file '%s' not found", call_stack_file);
        return 3;
    }

    call_stack_dump(exefile, call_stack_file);
    return 0;
}
