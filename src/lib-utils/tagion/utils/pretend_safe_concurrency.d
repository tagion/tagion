module tagion.utils.pretend_safe_concurrency;

private import concurrency = std.concurrency;

import core.time : Duration;
import std.meta : allSatisfy;
import std.traits : isSafe;
import std.exception;

/** @brief File contains functions of std.concurrency wrapped in @trusted
 *         to use them in @safe code
 */

public import std.concurrency : Tid,
    ThreadInfo,
    OwnerTerminated,
    LinkTerminated,
    TidMissingException,
    thisTid,
    PriorityMessageException,
    MailboxFull,
    OnCrowding,
    MessageMismatch,
    Variant;

void setMaxMailboxSize(Tid tid, size_t messages, OnCrowding doThis) @trusted {
    concurrency.setMaxMailboxSize(tid, messages, doThis);
}

void unregister(string name) @trusted {
    concurrency.unregister(name);
}

void send(Args...)(Tid tid, Args args) @trusted {
    concurrency.send(tid, args);
}

void prioritySend(Args...)(Tid tid, Args args) @trusted {
    concurrency.prioritySend(tid, args);
}

void receive(Args...)(Args args) @trusted if (allSatisfy!(isSafe, Args)) {
    concurrency.receive(args);
}

auto receiveOnly(T...)() @trusted {
    return concurrency.receiveOnly!T;
}

bool receiveTimeout(Args...)(Duration duration, Args ops) @trusted if (allSatisfy!(isSafe, Args)) {
    return concurrency.receiveTimeout(duration, ops);
}

Tid ownerTid() @trusted {
    return concurrency.ownerTid;
}

Tid spawn(F, Args...)(F fn, Args args) @trusted {
    return concurrency.spawn(fn, args);
}

Tid spawnLinked(F, Args...)(F fn, Args args) @trusted {
    return concurrency.spawnLinked(fn, args);
}
Tid locate(string name) @trusted nothrow {
    return assumeWontThrow(concurrency.locate(name));
}

bool register(string name, Tid tid) @trusted nothrow 
in (tid !is Tid.init) {
    return assumeWontThrow(concurrency.register(name, tid));
}
