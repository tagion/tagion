module tagion.utils.TrustedConcurrency;

private import concurrency = std.concurrency;

import core.time : Duration;

alias Tid = concurrency.Tid;
alias thisTid = concurrency.thisTid;

void sendTrusted(Args...)(Tid tid, Args args) @trusted
{
    concurrency.send(tid, args);
}

void prioritySendTrusted(Args...)(Tid tid, Args args) @trusted
{
    concurrency.prioritySend(tid, args);
}

void receiveTrusted(Args...)(Args args) @trusted
{
    concurrency.receive(args);
}

auto receiveOnlyTrusted(T...)() @trusted
{
    return concurrency.receiveOnly!T;
}

bool receiveTimeoutTrusted(T...)(Duration duration, T ops) @trusted
{
    return concurrency.receiveTimeout!T(duration, ops);
}

Tid ownerTidTrusted() @trusted
{
    return concurrency.ownerTid;
}

Tid spawnTrusted(F, Args...)(F fn, Args args) @trusted
{
    return concurrency.spawn(fn, args);
}

Tid locateTrusted(string name) @trusted
{
    return concurrency.locate(name);
}

bool registerTrusted(string name, Tid tid) @trusted
{
    return concurrency.register(name, tid);
}
