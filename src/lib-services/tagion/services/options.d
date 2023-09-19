/// Options for tagionwave services,
/// Publicly imports all service options
module tagion.services.options;
import std.traits;
import std.format;
import std.range;

static immutable(string) contract_sock_addr(const string prefix = "") @safe nothrow {
    import std.exception;

    version (linux) {
        return assumeWontThrow(format("abstract://%sNEUEWELLE_CONTRACT", prefix));
    }
    else version (Posix) {
        import std.path;
        import std.conv;
        import core.sys.posix.unistd : getuid;

        const uid = assumeWontThrow(getuid.to!string);
        return "ipc://" ~ buildPath("/", "run", "user", uid, assumeWontThrow(format("%stagionwave_contract.sock", prefix)));
    }
    else {
        assert(0, "Unsupported platform");
    }
}

enum NetworkMode {
    INTERNAL,
    LOCAL,
    PUB
}

@safe
struct WaveOptions {
    import tagion.utils.JSONCommon;

    NetworkMode network_mode = NetworkMode.INTERNAL;
    size_t number_of_nodes = 5;
    mixin JSONCommon;
}

@safe
struct TaskNames {
    public import tagion.utils.JSONCommon;

    string program = "tagion";
    string supervisor = "supervisor";
    string inputvalidator = "inputvalidator";
    string dart = "dart";
    string hirpc_verifier = "hirpc_verifier";
    string collector = "collector ";
    string transcript = "transcript";
    string tvm = "tvm";
    string epoch_creator = "epoch_creator";

    mixin JSONCommon;

    /// Set a prefix for the default options
    this(const string prefix) pure {
        setPrefix(prefix);
    }

    /**
        Inserts a prefix for all the task_names
        This function is used in mode 0.
    */
    void setPrefix(const string prefix) pure nothrow {
        import std.exception;

        alias This = typeof(this);
        alias FieldsNames = FieldNameTuple!This;
        static foreach (i, T; Fields!This) {
            static if (is(T == string)) {
                this.tupleof[i] = assumeWontThrow(format("%s%s", prefix, this.tupleof[i]));
            }
        }
    }
}

/// All options for neuewelle
@safe
struct Options {
    import std.json;
    import tagion.utils.JSONCommon;

    public import tagion.services.inputvalidator : InputValidatorOptions;
    public import tagion.services.DART : DARTOptions;
    public import tagion.services.hirpc_verifier : HiRPCVerifierOptions;
    public import tagion.services.collector : CollectorOptions;
    public import tagion.services.transcript : TranscriptOptions;
    public import tagion.services.TVM : TVMOptions;
    public import tagion.services.epoch_creator : EpochCreatorOptions;
    public import tagion.services.monitor : MonitorOptions;

    WaveOptions wave;
    InputValidatorOptions inputvalidator;
    HiRPCVerifierOptions hirpc_verifier;
    DARTOptions dart;
    CollectorOptions collector;
    TranscriptOptions transcript;
    TVMOptions tvm;
    EpochCreatorOptions epoch_creator;
    MonitorOptions monitor;

    TaskNames task_names;
    mixin JSONCommon;
    mixin JSONConfig;
    this(ref inout(Options) opt) inout pure nothrow @trusted {
        foreach (i, ref inout member; opt.tupleof) {
            this.tupleof[i] = member;
        }
    }

    static Options defaultOptions() nothrow {
        Options opts;
        setDefault(opts);
        return opts;
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
void setPrefix(Opt)(ref Opt opt, string prefix) nothrow if (is(Opt == struct)) {
    static if (__traits(hasMember, Opt, "setPrefix")) {
        opt.setPrefix(prefix);
    }
    static foreach (i, T; Fields!Opt) {
        static if (is(T == struct)) {
            setPrefix(opt.tupleof[i], prefix);
        }
    }
}

@safe
unittest {
    import std.stdio;

    enum prefix = "NodeX";
    Options opt = Options.defaultOptions;
    assert(opt.task_names.program[0 .. prefix.length] != prefix);
    assert(opt.task_names.transcript[0 .. prefix.length] != prefix);

    opt.task_names.setPrefix(prefix);
    immutable sub_opt = Options(opt);
    assert(sub_opt.task_names.program[0 .. prefix.length] == prefix);
    assert(sub_opt.task_names.transcript[0 .. prefix.length] == prefix);
}
