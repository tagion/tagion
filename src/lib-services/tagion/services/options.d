/// Options for tagionwave services,
/// Publicly imports all service options
module tagion.services.options;

@property
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
//@safe
struct Options {
    import std.json;
    import tagion.utils.JSONCommon;
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
}
