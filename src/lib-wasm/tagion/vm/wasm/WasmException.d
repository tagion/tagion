module tagion.vm.wavm.WasmException;

import tagion.TagionExceptions;

@safe
class WasmException : TagionException {
    this(string msg, string file = __FILE__, size_t line = __LINE__ ) {
        super( msg, file, line );
    }
}

alias check=Check!WasmException;
