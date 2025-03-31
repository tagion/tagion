module tagion.wasm.dkeyword;

@safe
struct DKeywords {
    enum words = [
        "__FILE_FULL_PATH__",
        "__FILE__",
        "__FUNCTION__", "__LINE__", "__MODULE__",
        "__PRETTY_FUNCTION__", "__gshared", "__parameters", "__rvalue", "__traits", "__vector",
        "abstract", "alias", "align", "asm", "assert", "auto", "body", "bool", "break", "byte", "case", "cast", "catch",
        "cdouble", "cent", "cfloat", "char", "class", "const", "continue", "creal", "dchar", "debug", "default",
        "delegate",
        "delete", "deprecated", "do", "double", "else", "enum", "export", "extern", "false", "final", "finally", "float",
        "for", "foreach", "foreach_reverse", "function", "goto", "idouble", "if", "ifloat", "immutable", "import", "in",
        "inout", "int", "interface", "invariant", "ireal", "is", "lazy", "long", "macro", "mixin", "module", "new",
        "nothrow",
        "null", "out", "override", "package", "pragma", "private", "protected", "public", "pure", "real", "ref", "return",
        "scope", "shared", "short", "static", "struct", "super", "switch", "synchronized", "template", "this", "throw",
        "true",
        "try", "typeid", "typeof", "ubyte", "ucent", "uint", "ulong", "union", "unittest", "ushort", "version", "void",
        "wchar", "while", "with",
    ];
    import std.algorithm;

    static assert(isSorted(words), "D Keyword list must be sorted");
    static bool isDKeyword(const(char[]) word) pure nothrow {
        bool innerKeyword(const uint index, const uint bisect) {
            if (index >= words.length) {
                return (bisect > 0) && innerKeyword(index - bisect, bisect >> 1);
            }
            if (word == words[index]) {
                return true;
            }
            if (bisect == 0) {
                return false;
            }
            if (word < words[index]) {
                return innerKeyword(index - bisect, bisect >> 1);
            }

            return innerKeyword(index + bisect, bisect >> 1);
        }

        import core.bitop;

        enum mid_index = cast(uint)(1 << bsr(words.length));

        return innerKeyword(mid_index, mid_index >> 1);
    }

}

alias isDKeyword = DKeywords.isDKeyword;

unittest {
    assert(isDKeyword("abstract"));
    assert(isDKeyword("function"));
    assert(isDKeyword("auto"));
    assert(isDKeyword("__FILE__"));
    assert(isDKeyword("with"));

    assert(!isDKeyword("not a keyword"));
    assert(!isDKeyword("aaa not a keyword"));
    assert(!isDKeyword("zzz not a keyword"));
    assert(!isDKeyword("aaa not a keyword"));
    assert(!isDKeyword("__AAA"));
}
