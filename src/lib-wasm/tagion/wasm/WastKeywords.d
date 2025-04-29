module tagion.wasm.WastKeywords;

import std.traits;

@safe:

enum WastKeywords {
    MODULE = "module",
    TYPE = "type",
    FUNC = "func",
    ELEM = "elem",
    TABLE = "table",
    IMPORT = "import",
    EXPORT = "export",
    MEMORY = "memory",
    SEGMENT = "segment",
    OFFSET = "offset",
    PARAM = "param",
    RESULT = "result",
    DECLARE = "declare",
}

bool isReseved(const(char[]) word) @nogc pure nothrow {
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
