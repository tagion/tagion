module tagion.utils.Result;

@safe
class UtilException : Exception {
    this( immutable(char)[] msg, string file = __FILE__, size_t line = __LINE__ ) pure nothrow {
        super( msg, file, line);
    }
}

@safe @nogc
struct Result(E) {
    E entry;
    immutable(UtilException) e;
    @disable this();
    this(E entry) pure nothrow {
        this.entry=entry;
        e=null;
    }
    this(E entry, string msg, string file = __FILE__, size_t line = __LINE__ ) pure nothrow {
        this.entry=entry;
        e=new UtilException(msg, file, line);
    }
    this(string msg, string file = __FILE__, size_t line = __LINE__ ) pure nothrow {
        this.entry=E.init;
        e=new UtilException(msg, file, line);
    }
    bool error() pure const nothrow {
        return e !is null;
    }
}
