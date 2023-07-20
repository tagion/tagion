/// Options for tagionwave services,
/// Publicly imports all service options
module tagion.services.options;

import tagion.utils.JSONCommon;
public import tagion.services.inputvalidator : InputValidatorOptions;
public import tagion.services.DART : DARTOptions;

@property
static immutable(string) contract_sock_path() @safe nothrow {
    version (linux) {
        return "\0NEUEWELLE_CONTRACT";
    }
    else version (Posix) {
        import std.path;
        import std.conv;
        import std.exception;
        import core.sys.posix.unistd : getuid;

        const uid = assumeWontThrow(getuid.to!string);
        return buildPath("/", "run", "user", uid, "tagionwave_contract.sock");
    }
    else {
        assert(0, "Unsupported platform");
    }
}

/// All options for neuewelle
struct Options {
    InputValidatorOptions inputvalidator;
    DARTOptions dart;
    mixin JSONCommon;
}
