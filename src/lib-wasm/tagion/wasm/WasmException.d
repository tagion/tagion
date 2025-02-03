module tagion.wasm.WasmException;

import tagion.errors.tagionexceptions;

@safe:

class WasmException : TagionException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow {
        super(msg, file, line);
    }
}

class WasmExprException : WasmException {
    import tagion.wasm.WasmBase;
    const ExprRange.IRElement elm;
    this(string msg, ref const(ExprRange.IRElement) elm, 
        string file = __FILE__, size_t line = __LINE__) pure nothrow {
        this.elm=elm;
        super(msg, file, line);
    }
}

alias check = Check!WasmException;
