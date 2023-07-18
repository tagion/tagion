/// Actor framework iplementation
/// Examles: [tagion.testbench.services]
module tagion.actor.actor;

import std.format : format;
import std.typecons;
import std.exception;
import std.traits;
import std.variant : Variant;
import std.format : format;
import std.traits;

import core.thread;
import core.time;

import concurrency = tagion.utils.pretend_safe_concurrency;
import tagion.logger.Logger;
import tagion.utils.Result;
import tagion.utils.pretend_safe_concurrency;
import tagion.actor.exceptions;
import tagion.basic.tagionexceptions : TagionException;

version (Posix) {
    import std.string : toStringz;
    import core.sys.posix.pthread;

    extern (C) int pthread_setname_np(pthread_t, const char*) nothrow;
}

/**
 * Message "Atom" type
 * Examples:
 * ---
 * // As a type
 * Msg!"hi";
 * // As a value
 * Msg!"hi"();
 * ---
 */
struct Msg(string name) {
}

// State messages send to the supervisor
enum Ctrl {
    UNKNOWN, // Unkwnown state
    STARTING, // The actors is lively
    ALIVE, /// Send to the ownerTid when the task has been started
    END, /// Send for the child to the ownerTid when the task ends
}

// Signals send from the supervisor to the direct children
enum Sig {
    STOP,
}

/// Control message sent to a supervisor
/// contains the Tid of the actor which send it and the state
alias CtrlMsg = Tuple!(string, "task_name", Ctrl, "ctrl");

private static Ctrl[string] childrenState;
private static string _task_name;
@property string task_name() @trusted {
    if (_task_name is string.init) {
        assert(0, "This thread is not a spawned actor");
    }
    return _task_name;
}

bool statusChildren(Ctrl ctrl) @safe nothrow {
    foreach (val; childrenState.byValue) {
        if (val != ctrl) {
            return false;
        }
    }
    return true;
}

/* 
 * Waif for the spawned child Actors of this thread to be in Ctrl state.
 * If it an Ctrl.END state it will free the children.
 * Returns: true if all of the get in Ctrl state before the timeout
 */
bool waitforChildren(Ctrl state, Duration timeout = 1.seconds) @safe nothrow {
    auto limit = MonoTime.currTime + timeout;
    try {
        while (!statusChildren(state) && MonoTime.currTime <= limit) {
            receiveTimeout(
                    timeout / childrenState.length,
                    (CtrlMsg msg) { childrenState[msg.task_name] = msg.ctrl; }
            );
        }
        log("%s", childrenState);
        if (state is Ctrl.END) {
            destroy(childrenState);
        }
        return statusChildren(state);
    }
    catch (Exception e) {
        return false;
    }
}

/// Checks if a type has the required members to be an actor
template isActor(A) {
    enum bool isActor = hasMember!(A, "task")
        && isCallable!(A.task);
}

template isActorHandle(T) {
    enum bool isActorHandle = __traits(isSame, TemplateOf!(T), ActorHandle);
}

template isFailHandler(F) {
    enum bool isFailHandler
        = is(F : void function(TaskFailure))
        || is(F : void delegate(TaskFailure));
}

/**
 * A "reference" to an actor that may or may not be spawned, we will never know
 * Params:
 *  A = an actor type
 */
struct ActorHandle(A) {
    /// the name of the possibly running task
    string task_name;

    /// the tid of the spawned task
    Tid tid() {
        return concurrency.locate(task_name);
    }

    // Get the status of the task, asserts if the calling task did not spawn it
    Ctrl state() @safe nothrow {
        if (task_name in childrenState) {
            return childrenState[task_name];
        }
        assert(0, "You don't own this task");
    }

    alias Actor = A;

    /// Send a message to this task
    void send(T...)(T args) @safe {
        concurrency.send(this.tid, args);
    }
}

/**
 * Create an actorHandle
 * Params:
 *   A = The type of actor you want to create a handle for
 *   task_name = the task name to search for
 * Returns: Actorhandle with type A
 * Examples:
 * ---
 * actorHandle!MyActor("my_task_name");
 * ---
 */
ActorHandle!A handle(A)(string task_name) @safe if (isActor!A) {
    return ActorHandle!A(task_name);
}

ActorHandle!A spawn(A, Args...)(immutable(A) actor, string name, Args args) @safe nothrow
if (isActor!A) {
    try {
        Tid tid;
        tid = concurrency.spawn((immutable(A) _actor, string name, Args args) @trusted nothrow {
            _task_name = name;
            log.register(name);
            stop = false;
            A actor = cast(A) _actor;
            setState(Ctrl.STARTING); // Tell the owner that you are starting.
            try {
                actor.task(args);
                // If the actor forgets to kill it's children we'll do it anyway
                if (!statusChildren(Ctrl.END)) {
                    foreach (child_task_name, ctrl; childrenState) {
                        if (ctrl is Ctrl.ALIVE) {
                            locate(child_task_name).send(Sig.STOP);
                        }
                    }
                    waitforChildren(Ctrl.END);
                }
            }
            catch (Exception t) {
                fail(t);
            }
            end;
        }, actor, name, args);
        childrenState[name] = Ctrl.UNKNOWN;
        log("spawning %s", name);
        tid.setMaxMailboxSize(int.sizeof, OnCrowding.throwException);
        if (concurrency.register(name, tid)) {
            log("%s registered as %s", tid, name);
        }
        else {
            log("could not register %s as %s, name already registered", tid, name);
        }
        return ActorHandle!A(name);
    }
    catch (Exception e) {
        assert(0, format("Exception: %s", e.msg));
    }
}

ActorHandle!A spawn(A, Args...)(string name, Args args) @safe nothrow
if (isActor!A) {
    immutable A actor;
    return spawn(actor, name, args);
}

/**
 * Params:
 *   A = The type of actor you want to create a handle for
 *   task_name = the name it should be started as
 *   args = list of arguments to pass to the task function
 * Returns: An actorHandle with type A
 * Examples:
 * ---
 * spawn!MyActor("my_task_name", 42);
 * ---
 */
// ActorHandle!A spawn(A, Args...)(string task_name, Args args) @safe nothrow
// if (isActor!A) {
//     A actor = A();
//     return spawn(actor, task_name, args);
// }

/*
 *
 * Params:
 *   a = an active actorhandle
 */
A respawn(A)(A actor_handle) @safe if (isActor!(A.Actor)) {
    actor_handle.send(Sig.STOP);
    unregister(actor_handle.task_name);

    return spawn!(A.Actor)(actor_handle.task_name);
}

/// Nullable and nothrow wrapper around ownerTid
Nullable!Tid tidOwner() @safe nothrow {
    // tid is "null"
    Nullable!Tid tid;
    try {
        // Tid is assigned
        tid = ownerTid;
    }
    catch (TidMissingException) {
        // Tid is "just null"
    }
    catch (Exception e) {
        // logger.fatal(e);
    }
    return tid;
}

/// Send to the owner if there is one
void sendOwner(T...)(T vals) @safe {
    if (!tidOwner.isNull) {
        concurrency.send(tidOwner.get, vals);
    }
    else {
        log.error("No owner tried to send a message to it");
        log.error("%s", tuple(vals));
    }
}

/** 
 * Send a TaskFailure up to the owner
 * Silently fails if there is no owner
 * Does NOT exit regular control flow
*/
void fail(Throwable t) @trusted nothrow {
    log(t);
    if (!tidOwner.isNull) {
        assumeWontThrow(
                ownerTid.prioritySend(
                TaskFailure(_task_name, cast(immutable) t)
        )
        );
    }
}

/// send your state to your owner
void setState(Ctrl ctrl) @safe nothrow {
    try {
        log("setting state to %s", ctrl);
        ownerTid.prioritySend(CtrlMsg(task_name, ctrl));
    }
    catch (Exception e) {
        log.error("Failed to set state");
        log(e);
    }
}

/// Cleanup and notify the supervisor that you have ended
void end() nothrow {
    assumeWontThrow(ThreadInfo.thisInfo.cleanup);
    setState(Ctrl.END);
}

static bool stop;
/* 
 * Params:
 *   task_name = the name of the task
 *   args = a list of message handlers for the task
 */
void run(Args...)(Args args) nothrow {
    // Check if a failHandler was passed as an arg
    static if (args.length == 1 && isFailHandler!(typeof(args[$ - 1]))) {
        enum failhandler = () {}; /// Use the fail handler passed through `args`
    }
    else {
        enum failhandler = (TaskFailure tf) {
            if (ownerTid != Tid.init) {
                ownerTid.prioritySend(tf);
            }
        };
    }

    setState(Ctrl.ALIVE); // Tell the owner that you are running
    while (!stop) {
        try {
            receive(
                    args, // The message handlers you pass to your Actor template
                    failhandler,
                    &signal,
                    &control,
                    &ownerTerminated,
                    &unknown,
            );
        }
        catch (Exception t) {
            fail(t);
        }
    }
}

void signal(Sig signal) {
    with (Sig) final switch (signal) {
    case STOP:
        stop = true;
        break;
    }
}

/// Controls message sent from the children.
void control(CtrlMsg msg) {
    childrenState[msg.task_name] = msg.ctrl;
}

/// Stops the actor if the supervisor stops
void ownerTerminated(OwnerTerminated) {
    log.trace("%s, Owner stopped... nothing to life for... stopping self", thisTid);
    stop = true;
}

/**
 * The default message handler, if it's an unknown messages it will send a FAIL to the owner.
 * Params:
 *   message = literally any message
 */
void unknown(Variant message) {
    throw new UnknownMessage("No delegate to deal with message: %s".format(message));
}
