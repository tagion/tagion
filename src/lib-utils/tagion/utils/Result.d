module tagion.utils.Result;

import tagion.basic.tagionexceptions;

@safe class UtilException : TagionException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow {
        super(msg, file, line);
    }
}

@safe struct Result(V) {
    V value;
    UtilException e;
    @disable this();
    @nogc this(V value) pure nothrow {
        this.value = value;
        e = null;
    }

    this(V value, string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow {
        this.value = value;
        e = new UtilException(msg, file, line);
    }

    this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow {
        this(V.init, msg, file, line);
    }

    @nogc bool error() pure const nothrow {
        return e !is null;
    }

    V get() {
        if (error) {
            throw e;
        }
        return value;
    }
}
