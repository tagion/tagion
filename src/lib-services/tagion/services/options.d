/// Options for tagionwave services,
/// Publicly imports all service options
module tagion.services.options;
import std.traits;
import std.format;
import std.range;

static immutable(string) contract_sock_path() @safe nothrow {
    version (linux) {
        version (NNG_INPUT) {
            return "abstract://NEUEWELLE_CONTRACT";
        }
        else {
            return "\0NEUEWELLE_CONTRACT";
        }
    }
    else version (Posix) {
        import std.path;
        import std.conv;
        import std.exception;
        import core.sys.posix.unistd : getuid;

        const uid = assumeWontThrow(getuid.to!string);
        return "ipc://" ~ buildPath("/", "run", "user", uid, "tagionwave_contract.sock");
    }
    else {
        assert(0, "Unsupported platform");
    }
}

/// All options for neuewelle
@safe
struct Options {
    import std.json;
    import tagion.utils.JSONCommon;

    string task_name = "tagion";
    public import tagion.services.inputvalidator : InputValidatorOptions;
    public import tagion.services.DART : DARTOptions;
    public import tagion.services.hirpc_verifier : HiRPCVerifierOptions;
    public import tagion.services.collector : CollectorOptions;
    public import tagion.services.transcript : TranscriptOptions;
    public import tagion.services.TVM : TVMOptions;

    InputValidatorOptions inputvalidator;
    HiRPCVerifierOptions hirpc_verifier;
    DARTOptions dart;
    CollectorOptions collector;
    TranscriptOptions transcript;
    TVMOptions tvm;
    mixin JSONCommon;
    mixin JSONConfig;
    this(ref inout(Options) opt, const string prefix = null) inout pure nothrow @trusted {

        foreach (i, ref inout member; opt.tupleof) {
            this.tupleof[i] = member;
        }
        if (!prefix.empty) {
            auto that = cast(Options*)&this;
            setTaskPrefix(*that, prefix);
        }
    }

    static Options defaultOptions() nothrow {
        Options opts;
        setDefault(opts);
        return opts;
    }
}

/**
    Inserts a prefix for all the task_name in Opt
    This function is used in mode 0.
*/
@safe
void setTaskPrefix(Opt)(ref Opt opt, const string prefix) pure nothrow if (is(Opt == struct)) {
    import std.exception;

    alias FieldsNames = FieldNameTuple!Opt;

    static foreach (i, T; Fields!Opt) {
        //foreach(i, ref member; opt.tupleof) {
        static if (is(T == string) && FieldsNames[i] == "task_name") {
            opt.tupleof[i] = assumeWontThrow(format("%s_%s", prefix, opt.tupleof[i]));
        }
        else static if (is(T == struct)) {
            setTaskPrefix(opt.tupleof[i], prefix);
        }

    }
}

@safe
void setDefault(Opt)(ref Opt opt) nothrow if (is(Opt == struct)) {
    static if (__traits(hasMember, Opt, "setDefault")) {
        opt.setDefault;

    }
    static foreach (i, T; Fields!Opt) {
        static if (is(T == struct)) {
            setDefault(opt.tupleof[i]);
        }
    }
}

@safe
unittest {
    import std.stdio;

    enum prefix = "NodeX";
    Options opt = Options.defaultOptions;
    assert(opt.task_name[0 .. prefix.length] != prefix);
    assert(opt.transcript.task_name[0 .. prefix.length] != prefix);

    immutable sub_opt = Options(opt, prefix);
    assert(sub_opt.task_name[0 .. prefix.length] == prefix);
    assert(sub_opt.transcript.task_name[0 .. prefix.length] == prefix);
}
