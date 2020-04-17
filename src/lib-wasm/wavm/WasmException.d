module wavm.WasmException;

import wavm.WavmException;

@safe
class WasmException : WavmException {
    this(string msg, string file = __FILE__, size_t line = __LINE__ ) pure {
        super( msg, file, line );
    }
}

alias check=Check!WasmException;
