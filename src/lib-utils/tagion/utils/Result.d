/// Result type that includes an exception
module tagion.utils.Result;

@safe
Result!V result(V)(V val) {
    return Result!V(val);
}

@safe struct Result(V, Except = Exception) {
    V value;
    Except e;
    @disable this();
    pure nothrow {
        @nogc this(V value) {
            this.value = value;
            e = null;
        }

        this(V value, string msg, string file = __FILE__, size_t line = __LINE__) {
            this.value = value;
            e = new Except(msg, file, line);
        }

        this(string msg, string file = __FILE__, size_t line = __LINE__) {
            this(V.init, msg, file, line);
        }

        this(Except e) @nogc {
            value = V.init;
            this.e = e;
        }

        string msg() const @nogc {
            return (e is null) ? null : e.msg;
        }

        bool error() const @nogc {
            return e !is null;
        }

        bool ok() const @nogc {
            return e is null;
        }

        bool opCast(T)() const @nogc if (is(T == bool)) {
            return (e is null) && (value !is V.init);
        }
    }
    V get() pure {
        if (error) {
            throw e;
        }
        return value;
    }
}
