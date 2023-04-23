module tagion.actor.actor;

import std.concurrency;
import std.stdio;
import std.format : format;
import std.typecons;
import core.thread;
import std.exception;
import std.traits;

import tagion.actor.exceptions;
import tagion.basic.tagionexceptions : TagionException, TaskFailure;

T receiveOnlyTimeout(T)() {
    T ret;
    receiveTimeout(
            1.seconds,
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

    void send(T...)(T vals) {
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
nothrow ActorHandle!A spawnActor(A, Args...)(string taskName, Args args) {
    alias task = A.task;
    Tid tid = assumeWontThrow(spawn(&task, args));
    assumeWontThrow(register(taskName, tid));

    return ActorHandle!A(tid, taskName);
}

/// Nullable and nothrow wrapper around ownerTid
nothrow Nullable!Tid tidOwner() {
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
nothrow void setState(Ctrl ctrl) {
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
    import std.concurrency : OwnerTerminated, Tid, thisTid, ownerTid, receive, prioritySend;
    import std.format : format;
    import std.traits : isCallable;
    import tagion.basic.tagionexceptions : TaskFailure, taskException;
    import std.stdio : writefln;
    import tagion.actor.exceptions : ActorException, UnknownMessage;

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

    version (none) void failHandler(TaskFailure tf) {
        assumeWontThrow({
            writeln("received exeption");
            //if (ownerTid != Tid.init) {
            ownerTid.send(tf);
            //}
        });
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
    nothrow void task() {
        try {

            setState(Ctrl.STARTING); // Tell the owner that you are starting.
            scope (exit)
                setState(Ctrl.END); // Tell the owner that you have finished.

            static if (__traits(hasMember, This, "children")) {
                debug writeln("STARTING CHILDREN", children);
                static foreach (i, child; children) {
                    {
                        alias Child = typeof(child);
                        debug writefln("STARTING: %s", i);
                        auto childhandle = spawnActor!Child(format("%s", i));
                        childrenState[childhandle.tid] = Ctrl.STARTING; // assume that the child is starting
                    }
                }

                // TODO: Should have a timeout incase the children don't commit alive;
                debug writeln((childrenState.all(Ctrl.ALIVE)));
                while (!(childrenState.all(Ctrl.ALIVE))) {
                    CtrlMsg msg = receiveOnly!CtrlMsg; // HACK: don't use receiveOnly
                    childrenState[msg.tid] = msg.ctrl;
                }

                debug writeln((childrenState.all(Ctrl.ALIVE)));
                debug writeln("STARTED all the children");
            }

            // Call starting() if it's implemented
            static if (__traits(hasMember, This, "starting")) {
                alias startingCall = __traits(getMember, This, "starting");
                static assert(isCallable!startingCall, "the starting callback is not callable");
                startingCall();
            }

            static if (__traits(hasMember, This, "fail")) {
                auto failhandler = __traits(getMember, This, "fail");
            }
            else {
                auto failhandler = (TaskFailure tf) {
                    writeln("received exeption");
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
                            (immutable Exception t) {
                        if (ownerTid != Tid.init) {
                            ownerTid.prioritySend(t);
                        }
                    },
                            &signal,
                            &control,
                            &ownerTerminated,
                            &unknown,
                    );
                }
                catch (Exception t) {
                    assumeWontThrow(writefln("caught exeption"));
                    if (ownerTid != Tid.init) {
                        ownerTid.prioritySend(TaskFailure(cast(immutable) t, "sometask"));
                    }
                }
            }
        }

        // If we catch an exception we send it back to owner for them to deal with it.
        catch (Exception e) {
            immutable failure = taskFailure(e, "some_unknown_task");
            assumeWontThrow(ownerTid.prioritySend(failure));
        }
    }
}
