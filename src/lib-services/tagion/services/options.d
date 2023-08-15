/// Options for tagionwave services,
/// Publicly imports all service options
module tagion.services.options;

import tagion.utils.JSONCommon;
public import tagion.services.inputvalidator : InputValidatorOptions;
public import tagion.services.DART : DARTOptions;
public import tagion.services.hirpc_verifier : HiRPCVerifierOptions;

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
struct Options {
    InputValidatorOptions inputvalidator;
    DARTOptions dart;
    HiRPCVerifierOptions hirpc_verifier;
    mixin JSONCommon;
}
