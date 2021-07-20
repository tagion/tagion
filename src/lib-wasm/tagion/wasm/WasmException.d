module tagion.wasm.WasmException;

import tagion.basic.TagionExceptions;

@safe class WasmException : TagionException
{
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure
    {
        super(msg, file, line);
    }
}

alias check = Check!WasmException;
