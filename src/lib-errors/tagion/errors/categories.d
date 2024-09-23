module tagion.errors.categories;

@safe:
enum ERRORS {
    HIBON = 10_000, /// HiBON format errors 
    HASHGRAPH = 11_000, /// Hashgraph consensus errors
    GOSSIPNET = 12_000, /// Gossip-network errors
    DART = 13_000, /// DART Database errors
    SECURITY = 14_000, /// Security errors signing and verification
    CIPHER = 15_000, /// Encryption and Decryptions errors
    CREDITIAL = 16_000, /// Network and contracts Authentications 
    NETWORK = 17_000, /// Basic network errors
    TVM = 18_000, /// Tagion virtual machine errors
}

void fwrite(Errors)(string filename) if (is(Errors == enum)) {
    import std.json;
    import std.traits;
    import std.conv : to;
    import std.file;

    JSONValue json;
    static foreach (E; EnumMembers!Errors) {
        json[E.stringof] = E.to!int;
    }
    filename.write(json.toPrettyString);
}

void check_errors(Errors)(string filename) nothrow if (is(Errors == enum)) {
    import std.json;
    import std.traits;
    import std.conv : to;
    import std.file;
    import std.exception;
    import std.algorithm;
    import std.string;
    import tagion.basic.Debug : __format;

    void do_stuff() @safe nothrow {
        try {
            const text = filename.readText;
            auto json = parseJSON(text);
            static foreach (E; EnumMembers!Errors) {
                {
                    const error_no = json[E.stringof].integer;
                    assert(E.to!int == error_no,
                            __format("Error code %s has changes from %d to %d", E.stringof, E.to!int, error_no));
                }
            }
            string[] keys;
            (() @trusted {
                foreach (string key, j; json) {
                    keys ~= key;
                }
            })();
            auto error_names = [EnumMembers!Errors].map!(e => e.to!string);
            auto undefined_errors = keys.filter!(key => !error_names.canFind(key));
            assert(undefined_errors.empty,
                    __format("Errors declared in %s file, but is not defined in %s (Not defined = %s)",
                    filename, Errors.stringof, undefined_errors));
        }
        catch (Exception e) {
            import std.stdio;

            assumeWontThrow((() @trusted => e.toString.splitLines.each!writeln)());
            assert(0, e.msg);
        }
    }

    do_stuff;
}

unittest {
    import tagion.basic.testbasic;

    const category_file = unitfile("categories.json");
    version (UPDATE_ERROR_CATEGORIES)
        category_file.fwrite!ERRORS;
    category_file.check_errors!ERRORS;
}
