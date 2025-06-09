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

    OFFSET = "offset",
    PARAM = "param",
    RESULT = "result",
    DECLARE = "declare",
    ITEM = "item",
    FUNCREF = "funcref",
    EXTERN = "extern",
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
