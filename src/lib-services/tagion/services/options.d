/// Options for tagionwave services,
/// Publicly imports all service options
module tagion.services.options;
import std.format;
import std.range;
import std.traits;

import tagion.basic.dir;

/// This function should be renamed
/// Initially there it was only intended to be used for the contract address for the inputvalidator
immutable(string) contract_sock_addr(const string prefix = "") @safe nothrow {
    version (linux) {
        return "abstract://" ~ prefix ~ "NEUEWELLE";
    }
    else version (Posix) {
        import std.path;
        import std.exception;

        return "ipc://" ~ buildPath(assumeWontThrow(base_dir.run), prefix ~ "tagionwave_contract.sock");
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

    import tagion.json.JSONRecord;

    /** Read node addresses from this files if it's defined
     *  Useful for development
     *  Formatted likes this. With 1 entry per line.
     *  <Base64 encoded public key> <address>
    */
    string address_file;
    NetworkMode network_mode = NetworkMode.INTERNAL;
    uint number_of_nodes = 5;
    string prefix_format = "Node_%s_";

    // The program stops if an actor taskfailure reaches the top thread
    bool fail_fast = true;

    mixin JSONRecord;
}

public import tagion.services.tasknames : TaskNames;

public import tagion.logger.LoggerOptions : LoggerOptions;
public import tagion.services.DART : DARTOptions;
public import tagion.services.DARTInterface : DARTInterfaceOptions;
public import tagion.services.collector : CollectorOptions;
public import tagion.services.epoch_creator : EpochCreatorOptions;
public import tagion.services.hirpc_verifier : HiRPCVerifierOptions;
public import tagion.services.inputvalidator : InputValidatorOptions;
public import tagion.services.replicator : ReplicatorOptions;
public import tagion.services.subscription : SubscriptionServiceOptions;
version(NEW_TRANSCRIPT) {
public import tagion.services.trans : TranscriptOptions;
} else {
public import tagion.services.transcript : TranscriptOptions;
}
public import tagion.services.TRTService : TRTOptions;
public import tagion.services.nodeinterface : NodeInterfaceOptions;
public import tagion.services.DARTSynchronization : DARTSyncOptions;

/// All options for neuewelle
@safe
struct Options {
    import std.json;
    import tagion.json.JSONRecord;

    WaveOptions wave;
    InputValidatorOptions inputvalidator;
    HiRPCVerifierOptions hirpc_verifier;
    DARTOptions dart;
    EpochCreatorOptions epoch_creator;
    ReplicatorOptions replicator;
    DARTInterfaceOptions dart_interface;
    SubscriptionServiceOptions subscription;
    LoggerOptions logger;
    TRTOptions trt;
    NodeInterfaceOptions node_interface;
    DARTSyncOptions sync;

    TaskNames task_names;
    mixin JSONRecord;
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

    opt.setPrefix(prefix);
    immutable sub_opt = Options(opt);
    assert(sub_opt.task_names.program[0 .. prefix.length] == prefix);
    assert(sub_opt.task_names.transcript[0 .. prefix.length] == prefix);
}
