module tagion.wasm.WastKeywords;

import std.traits;

@safe:

enum WastKeywords {
    MODULE = "module",

    TYPE = "type",
    IMPORT = "import",
    FUNC = "func",
    TABLE = "table",
    MEMORY = "memory",
    GLOBAL = "global",
    EXPORT = "export",
    ELEM = "elem",
    SEGMENT = "segment",
    DATA = "data",

    OFFSET = "offset",
    PARAM = "param",
    RESULT = "result",
    DECLARE = "declare",
    ITEM = "item",
    FUNCREF = "funcref",
    EXTERN = "extern",
    // Assert keywords
    ASSERT_RETURN_NAN = "assert_return_nan",
    ASSERT_RETURN = "assert_return",
    ASSERT_TRAP = "assert_trap",
    ASSERT_INVALID = "assert_invalid",
}

bool isReserved(const(char[]) word) @nogc pure nothrow {
    switch (word) {
        static foreach (E; [EnumMembers!WastKeywords]) {
    case E:
        }
        return true;
    default:
        return false;
    }
    assert(0);
}
