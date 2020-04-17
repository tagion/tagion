module wavm.WavmException;

/++
 + Exception used as a base exception class for all exceptions use in tagion project
 +/
@safe
class WavmException : Exception {
    this(string msg, string file = __FILE__, size_t line = __LINE__ ) pure {
        super( msg, file, line );
    }
}

@safe
void Check(E)(bool flag, lazy string msg, string file = __FILE__, size_t line = __LINE__) pure {
    if (!flag) {
        throw new E(msg, file, line);
    }
}
