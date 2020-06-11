module tagion.GlobalSignals;
import tagion.basic.Basic: abort;
import core.stdc.signal;
import std.stdio;
import core.stdc.stdlib: exit;

static extern(C) void shutdown(int sig) @nogc nothrow {

    printf("Shutdown sig %d about=%d\n\0".ptr, sig, abort);
    if (sig is SIGINT || sig is SIGTERM) {
        if(abort){
            exit(0);
        }
        abort=true;
    }
//    printf("Shutdown sig %d\n\0".ptr, sig);
}

import core.stdc.signal;
enum SIGPIPE=13; // SIGPIPE is not defined in the module core.stdc.signal
static extern(C) void ignore(int sig) @nogc nothrow {
    printf("Ignore sig %d\n\0".ptr, sig);
}
shared static this() {
    signal(SIGPIPE, &ignore);
    signal(SIGINT, &shutdown);
    signal(SIGTERM, &shutdown);
}
