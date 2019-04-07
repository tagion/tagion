module tagion.services.TagionLog;

import std.stdio;

static File log;

static this() {
    log=stdout;
}
