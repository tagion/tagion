module tagion.network.NetworkExceptions;

import tagion.basic.tagionexceptions : Check, TagionException;

@safe
class SocketMaxDataSize : TagionException {
    this(immutable(char)[] msg, string file = __FILE__, size_t line = __LINE__) pure {
        super(msg, file, line);
    }
}

alias check = Check!SocketMaxDataSize;
