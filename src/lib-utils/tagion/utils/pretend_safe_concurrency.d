module tagion.utils.pretend_safe_concurrency;

private import concurrency = std.concurrency;

import core.time : Duration;

/** @brief File contains functions of std.concurrency wrapped in @trusted
 *         to use them in @safe code
 */

alias Tid = concurrency.Tid;
alias thisTid = concurrency.thisTid;
alias ThreadInfo = concurrency.ThreadInfo;
alias OwnerTerminated = concurrency.OwnerTerminated;

void send(Args...)(Tid tid, Args args) @trusted
{
    concurrency.send(tid, args);
}

void prioritySend(Args...)(Tid tid, Args args) @trusted
{
    concurrency.prioritySend(tid, args);
}

void receive(Args...)(Args args) @trusted
{
    concurrency.receive(args);
}

auto receiveOnlyTrusted(T...)() @trusted
{
    return concurrency.receiveOnly!T;
}

bool receiveTimeout(T...)(Duration duration, T ops) @trusted
{
    return concurrency.receiveTimeout!T(duration, ops);
}

Tid ownerTid() @trusted
{
    return concurrency.ownerTid;
}

Tid spawn(F, Args...)(F fn, Args args) @trusted
{
    return concurrency.spawn(fn, args);
}

Tid locate(string name) @trusted
{
    return concurrency.locate(name);
}

bool register(string name, Tid tid) @trusted
{
    return concurrency.register(name, tid);
}
