import tagion.errors.tagionexceptions;

@safe
class NetworkException : TagionException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow {
        super(msg, file, line);
    }
}

alias check = Check!NetworkException;
