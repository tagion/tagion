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
import std.meta;

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

struct Request(string name) {
    Msg!name msg;
    uint id;
    string task_name;

    static Request opCall() @safe {
        import tagion.utils.Random;

        Request!name r;
        r.msg = Msg!name();
        r.id = generateId();
        r.task_name = thisActor.task_name;
        return r;
    }

    alias Response = .Response!name;

    void respond(Args...)(Args args) {
        auto res = Response(msg, id);
        locate(task_name).send(res, args);
    }
}

struct Response(string name) {
    Msg!name msg;
    uint id;
}

@safe
unittest {
    thisActor.task_name = "req_resp";
    register("req_resp", thisTid);
    alias Some_req = Request!"some_req";
    void some_responder(Some_req req) {
        req.respond("hello");
    }

    auto created_req = Some_req();
    some_responder(created_req);
    int received = receiveTimeout(Duration.zero, (Some_req.Response res, string _) {
        assert(created_req.msg == res.msg, "request msg were not the same");
        assert(created_req.id == res.id, "request id were not the same");
    });
    assert(received, "never received response");
}

// State messages send to the supervisor
enum Ctrl {
    UNKNOWN, // Unkwnown state
    STARTING, // The actors is starting
    ALIVE, /// The actor is running
    END, /// The actor is stopping
}

// Signals send from the supervisor to the direct children
enum Sig {
    STOP,
}

struct ActorInfo {
    private Ctrl[string] childrenState;
    string task_name;
    bool stop;
}

static ActorInfo thisActor;

/// Control message sent to a supervisor
/// contains the Tid of the actor which send it and the state
alias CtrlMsg = Tuple!(string, "task_name", Ctrl, "ctrl");

bool statusChildren(Ctrl ctrl) @safe nothrow {
    foreach (val; thisActor.childrenState.byValue) {
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
                    timeout / thisActor.childrenState.length,
                    (CtrlMsg msg) { thisActor.childrenState[msg.task_name] = msg.ctrl; }
            );
        }
        log("%s", thisActor.childrenState);
        if (state is Ctrl.END) {
            destroy(thisActor.childrenState);
        }
        return statusChildren(state);
    }
    catch (Exception e) {
        return false;
    }
}

/// Checks if a type has the required members to be an actor
enum bool isActor(A) = hasMember!(A, "task") && isCallable!(A.task) && isSafe!(A.task);

enum bool isActorHandle(T) = __traits(isSame, TemplateOf!(T), ActorHandle);

enum bool isFailHandler(F)
    = is(F : void function(TaskFailure))
    || is(F : void delegate(TaskFailure));

/// Stolen from std.concurrency;
template isSpawnable(F, T...) {
    template isParamsImplicitlyConvertible(F1, F2, int i = 0) {
        alias param1 = Parameters!F1;
        alias param2 = Parameters!F2;
        static if (param1.length != param2.length)
            enum isParamsImplicitlyConvertible = false;
        else static if (param1.length == i)
            enum isParamsImplicitlyConvertible = true;
        else static if (isImplicitlyConvertible!(param2[i], param1[i]))
            enum isParamsImplicitlyConvertible = isParamsImplicitlyConvertible!(F1,
                        F2, i + 1);
        else
            enum isParamsImplicitlyConvertible = false;
    }

    enum isSpawnable = isCallable!F && is(ReturnType!F : void)
        && isParamsImplicitlyConvertible!(F, void function(T))
        && (isFunctionPointer!F || !hasUnsharedAliasing!F);
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
        if (task_name in thisActor.childrenState) {
            return thisActor.childrenState[task_name];
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
 * handle!MyActor("my_task_name");
 * ---
 */
ActorHandle!A handle(A)(string task_name) @safe if (isActor!A) {
    return ActorHandle!A(task_name);
}

ActorHandle!A spawn(A, Args...)(immutable(A) actor, string name, Args args) @safe nothrow
if (isActor!A && isSpawnable!(typeof(A.task), Args)) {
    try {
        Tid tid;
        tid = concurrency.spawn((immutable(A) _actor, string name, Args args) @trusted nothrow{
            thisActor.task_name = name;
            log.register(name);
            thisActor.stop = false;
            A actor = cast(A) _actor;
            setState(Ctrl.STARTING); // Tell the owner that you are starting.
            try {
                actor.task(args);
                // If the actor forgets to kill it's children we'll do it anyway
                if (!statusChildren(Ctrl.END)) {
                    foreach (child_task_name, ctrl; thisActor.childrenState) {
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
        thisActor.childrenState[name] = Ctrl.UNKNOWN;
        log("spawning %s", name);
        tid.setMaxMailboxSize(int.max, OnCrowding.throwException);
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
    catch (Exception _) {
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
    try {
        debug (actor)
            log(t);
        ownerTid.prioritySend(TaskFailure(thisActor.task_name, cast(immutable) t));
    }
    catch (Exception e) {
        log.fatal("Failed to deliver TaskFailure: \n
                %s\n\n
                Because:\n
                %s", t, e);
        log.fatal("Stopping because we failed to deliver a TaskFailure to the supervisor");
        thisActor.stop = true;
    }
}

/// send your state to your owner
void setState(Ctrl ctrl) @safe nothrow {
    try {
        log("setting state to %s", ctrl);
        ownerTid.prioritySend(CtrlMsg(thisActor.task_name, ctrl));
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

/* 
 * Params:
 *   task_name = the name of the task
 *   args = a list of message handlers for the task
 */
void run(Args...)(Args args) @safe nothrow
if (allSatisfy!(isSafe, Args)) {
    // Check if a failHandler was passed as an arg
    static if (args.length == 1 && isFailHandler!(typeof(args[$ - 1]))) {
        enum failhandler = () @safe {}; /// Use the fail handler passed through `args`
    }
    else {
        enum failhandler = (TaskFailure tf) @safe {
            if (!tidOwner.isNull) {
                ownerTid.prioritySend(tf);
            }
        };
    }

    setState(Ctrl.ALIVE); // Tell the owner that you are running
    while (!thisActor.stop) {
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

/** 
 * 
 * Params:
 *   duration = the duration for the timeout
 *   timeout = delegate function to call
 *   args = normal message handlers for the task
 */
void runTimeout(Args...)(Duration duration, void delegate() @safe timeout, Args args) nothrow
if (allSatisfy!(isSafe, Args)) {
    // Check if a failHandler was passed as an arg
    static if (args.length == 1 && isFailHandler!(typeof(args[$ - 1]))) {
        enum failhandler = () @safe {}; /// Use the fail handler passed through `args`
    }
    else {
        enum failhandler = (TaskFailure tf) @safe {
            if (!tidOwner.isNull) {
                ownerTid.prioritySend(tf);
            }
        };
    }

    setState(Ctrl.ALIVE); // Tell the owner that you are running
    while (!thisActor.stop) {
        try {
            const message = receiveTimeout(
                    duration,
                    args, // The message handlers you pass to your Actor template
                    failhandler,
                    &signal,
                    &control,
                    &ownerTerminated,
                    &unknown,
            );
            if (!message) {
                timeout();
            }
        }
        catch (Exception t) {
            fail(t);
        }
    }
}

void signal(Sig signal) @safe {
    with (Sig) final switch (signal) {
    case STOP:
        thisActor.stop = true;
        break;
    }
}

/// Controls message sent from the children.
void control(CtrlMsg msg) @safe {
    thisActor.childrenState[msg.task_name] = msg.ctrl;
}

/// Stops the actor if the supervisor stops
void ownerTerminated(OwnerTerminated) @safe {
    log.trace("%s, Owner stopped... nothing to life for... stopping self", thisTid);
    thisActor.stop = true;
}

/**
 * The default message handler, if it's an unknown messages it will send a FAIL to the owner.
 * Params:
 *   message = literally any message
 */
void unknown(Variant message) @trusted {
    throw new UnknownMessage("No delegate to deal with message: %s".format(message));
}
