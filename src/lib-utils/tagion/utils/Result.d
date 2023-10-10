module tagion.utils.Result;

@safe
Result!V result(V)(V val) {
    return Result!V(val);
}

@safe struct Result(V, Except = Exception) {
    V value;
    Except e;
    @disable this();
    @nogc this(V value) pure nothrow {
        this.value = value;
        e = null;
    }

    this(V value, string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow {
        this.value = value;
        e = new Except(msg, file, line);
    }

    this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow {
        this(V.init, msg, file, line);
    }

    this(Except e) @nogc pure nothrow {
        value = V.init;
        this.e = e;
    }

    @nogc string msg() pure const nothrow {
        return (e is null) ? null : e.msg;
    }

    @nogc bool error() pure const nothrow {
        return e !is null;
    }

    bool opCast(T)() pure const nothrow if (is(T == bool)) {
        return (e is null) && (value !is V.init);
    }

    V get() {
        if (error) {
            throw e;
        }
        return value;
    }
}
