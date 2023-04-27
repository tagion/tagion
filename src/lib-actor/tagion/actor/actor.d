module tagion.actor.actor;

import std.concurrency;
import std.stdio;
import std.format : format;
import std.typecons;
import core.thread;
import std.exception;
import std.traits;

import tagion.actor.exceptions;
import tagion.actor.exceptions : TaskFailure;
import tagion.basic.tagionexceptions : TagionException;

T receiveOnlyTimeout(T)() {
    T ret;
    receiveTimeout(
            2.seconds,
            (T val) { ret = val; },
            (Variant val) {
        throw new MessageMismatch(
            format("Unexpected message got %s of type %s, expected %s", val, val.type.toString(), T.stringof));
    }
    );

    if (ret is T.init) {
        throw new MessageTimeout(
                format("Timed out never received message expected message type: %s".format(T.stringof))
        );
    }

    return ret;
}

bool all(Ctrl[Tid] aa, Ctrl ctrl) {
    foreach (val; aa) {
        if (val != ctrl) {
            return false;
        }
    }
    return true;
}

/// Exception sent when the actor gets a message that it doesn't handle
class UnknownMessage : TagionException {
    this(immutable(char)[] msg, string file = __FILE__, size_t line = __LINE__) pure {
        super(msg, file, line);
    }
}

// Exception when the actor fails to start or stop
class RunFailure : TagionException {
    this(immutable(char)[] msg, string file = __FILE__, size_t line = __LINE__) pure {
        super(msg, file, line);
    }
}

@trusted
static immutable(TaskFailure) taskFailure(Throwable e, string taskName) @nogc nothrow { //if (is(T:Throwable) && !is(T:TagionExceptionInterface)) {
    return immutable(TaskFailure)(cast(immutable) e, taskName);
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
    STARTING, // The actors is lively
    ALIVE, /// Send to the ownerTid when the task has been started
    END, /// Send for the child to the ownerTid when the task ends
}

// Signals send from the supervisor to the direct children
enum Sig {
    STOP,
}

debug (actor) enum DebugSig {
    /* STARTING = Msg!"STARTING", */
    FAIL, // Artificially make the actor fail
}

/// Control message sent to a supervisor
/// contains the Tid of the actor which send it and the state
alias CtrlMsg = Tuple!(Tid, "tid", Ctrl, "ctrl");

/// Don't use this
bool checkCtrl(Ctrl msg) {
    // Never use receiveOnly
    auto r = receiveOnly!(CtrlMsg);
    debug writeln(r);
    return r[1] is msg;
}

/**
 * A "reference" to an actor that may or may not be spawned, we will never know
 * Params:
 *  A = an actor type
 */
struct ActorHandle(A) {
    import concurrency = std.concurrency;

    /// the tid of the spawned task
    Tid tid;
    /// the name of the possibly running task
    string taskName;

    @trusted void send(T...)(T vals) {
        concurrency.send(tid, vals);
    }

    /// use
    void opDispatch(string method, Args...)(Args args) {
        send(actor.Msg!method, args);
    }

}

/**
 * Create an actorHandle
 * Params:
 *   A = The type of actor you want to create a handle for
 *   taskName = the task name to search for
 * Returns: Actorhandle with type A
 * Examples:
 * ---
 * actorHandle!MyActor("my_task_name");
 * ---
 */
ActorHandle!A actorHandle(A)(string taskName) {
    Tid tid = locate(taskName);
    return ActorHandle!A(tid, taskName);
}

/**
 * Params:
 *   A = The type of actor you want to create a handle for
 *   taskName = the name it should be started as
 *   args = list of arguments to pass to the task function
 * Returns: An actorHandle with type A
 * Examples:
 * ---
 * spawnActor!MyActor("my_task_name", 42);
 * ---
 */
ActorHandle!A spawnActor(A)(string taskName) @trusted nothrow {
    alias task = A.task;
    Tid tid;

    //Tid isSpawnedTid = assumeWontThrow(locate(taskName));
    //if (isSpawnedTid is Tid.init) {
    tid = assumeWontThrow(spawn(&task, taskName)); /// TODO: set oncrowding to exception;
    assumeWontThrow(register(taskName, tid));
    assumeWontThrow(writefln("%s registered", taskName));
    //}

    return ActorHandle!A(tid, taskName);
}

/// Nullable and nothrow wrapper around ownerTid
Nullable!Tid tidOwner() nothrow {
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
void sendOwner(T...)(T vals) {
    if (!tidOwner.isNull) {
        send(tidOwner.get, vals);
    }
    // Otherwise writr a message to the logger instead,
    // Otherwise just write it to stdout;
    else {
        write("No owner, writing message to stdout instead: ");
        writeln(vals);
        // Log
    }
}

/// send your state to your owner
void setState(Ctrl ctrl) nothrow {
    try {
        if (!tidOwner.isNull) {
            tidOwner.get.prioritySend(CtrlMsg(thisTid, ctrl));
        }
        else {
            /* write("No owner, writing message to stdout instead: "); */
            /* writeln(ctrl); */
        }
    }
    catch (PriorityMessageException e) {
        /* logger.fatal(e); */
    }
    catch (Exception e) {
        /* logger.fatal(e); */
    }
}

/**
 * Base template
 * All members should be static
 * Examples: See [Actor examples]($(DOC_ROOT_OBJECTS)tagion.actor.example$(DOC_EXTENSION))
 *
 * Struct may implement starting callback that gets called after the actor sends Ctrl.STARTING
 * ---
 * void starting() {...};
 * ---
 */
mixin template Actor(T...) {
static:
    import std.exception : assumeWontThrow;
    import std.variant : Variant;
    import std.concurrency : OwnerTerminated, Tid, thisTid, ownerTid, receive, prioritySend, ThreadInfo;
    import std.format : format;
    import std.traits : isCallable;
    import tagion.actor.exceptions : TaskFailure, taskException, ActorException, UnknownMessage;
    import std.stdio : writefln, writeln;

    bool stop = false;
    Ctrl[Tid] childrenState; // An AA to keep a copy of the state of the children

    alias This = typeof(this);

    void signal(Sig signal) {
        with (Sig) final switch (signal) {
        case STOP:
            stop = true;
            break;
        }
    }

    /// Controls message sent from the children.
    void control(CtrlMsg msg) {
        childrenState[msg.tid] = msg.ctrl;
    }

    /// Stops the actor if the supervisor stops
    void ownerTerminated(OwnerTerminated) {
        writefln("%s, Owner stopped... nothing to life for... stopping self", thisTid);
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

    /// The tasks that get run when you call spawnActor!
    void task(string taskName) nothrow {
        try {

            setState(Ctrl.STARTING); // Tell the owner that you are starting.
            scope (exit) {
                version (none)
                    if (childrenState.length != 0) {
                        foreach (tid, ctrl; childrenState) {
                            if (ctrl is Ctrl.ALIVE) {
                                tid.send(Sig.STOP);
                            }
                        }

                        while (!(childrenState.all(Ctrl.END))) {
                            CtrlMsg msg;
                            receive(
                                    (CtrlMsg ctrl) { msg = ctrl; }
                            );
                            childrenState[msg.tid] = msg.ctrl;
                        }
                    }

                ThreadInfo.thisInfo.cleanup;
                setState(Ctrl.END); // Tell the owner that you have finished.
            }

            // Call starting() if it's implemented
            static if (__traits(hasMember, This, "starting")) {
                alias startingCall = __traits(getMember, This, "starting");
                static assert(isCallable!startingCall, "the starting callback is not callable");
                startingCall();
            }

            // Asign the failhandler if a custom one is defined override the default one
            static if (__traits(hasMember, This, "fail")) {
                auto failhandler = __traits(getMember, This, "fail");
            }
            else {
                // default failhandler
                auto failhandler = (TaskFailure tf) {
                    if (ownerTid != Tid.init) {
                        ownerTid.prioritySend(tf);
                    }
                };
            }

            setState(Ctrl.ALIVE); // Tell the owner that you running
            while (!stop) {
                try {
                    receive(
                            T, // The message handlers you pass to your Actor template
                            failhandler,
                            &signal,
                            &control,
                            &ownerTerminated,
                            &unknown,
                    );
                }
                catch (Throwable t) {
                    if (ownerTid != Tid.init) {
                        ownerTid.prioritySend(TaskFailure(cast(immutable) t, taskName));
                    }
                }
            }
        }

        // If we catch an exception we send it back to owner for them to deal with it.
        catch (Throwable t) {
            if (tidOwner.get !is Tid.init) {
                assumeWontThrow(ownerTid.prioritySend(TaskFailure(cast(immutable) t, taskName)));
            }
        }
    }
}
