module tagion.actor.actor;

import std.concurrency;
import std.stdio;
import std.format : format;
import std.typecons;
import core.thread;
import std.exception;

/* AssociativeArray; */
bool all(Ctrl[Tid] AA, Ctrl ctrl)
/* if(unaryFun!Pred) */
{
    foreach(val; AA) {
        if ( val != ctrl ) {
            return false;
        }
    }
    return true;
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
    FAIL, /// This if a something failed other than an exception
    END, /// Send for the child to the ownerTid when the task ends
}

// Signals send from the supervisor to the direct children
enum Sig {
    STOP,
}

debug enum DebugSig {
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
struct ActorHandle(A) if (isActor!A) {
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
nothrow ActorHandle!A spawnActor(A, Args...)(string taskName, Args args)
if (isActor!A) {
    alias task = A.task;
    Tid tid = assumeWontThrow(spawn(&task, args));
    assumeWontThrow(register(taskName, tid));

    return ActorHandle!A(tid, taskName);
}

import std.meta;
alias TaskHandle = AliasSeq!(Actor, string);


// Delegate for dealing with exceptions sent from children
version (none) void exceptionHandler(Exception e) {
    // logger.fatal(e);
    writeln(e);
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

version (none) Tid[] spawnChildren(A)(A[] fns)  {
    Tid[] tids;
    foreach (f; fns) {
        // Starting and checking the children sequentially 🤮
        // Also bootstrapping
        tids ~= spawn(A);
        assert(checkCtrl(Ctrl.STARTING));
        assert(checkCtrl(Ctrl.ALIVE));
    }
    return tids;
}

/**
 * Base class for actor
 * All members should be static
 * Descendants should implement task and it should be nothrow
 * Examples: See [Actor examples]($(DOC_ROOT_OBJECTS)tagion.actor.example$(DOC_EXTENSION))
 */
abstract class Actor {
static:
    /**
     * The running task function your actor should implement
     */
    void task() nothrow;

    /* ActorTask[string] children; // A list of children that the actor supervises */
    Ctrl[Tid] childrenState; // An
    ///Deprecated: startChildren
    bool[Tid] startChildren; // An associative array of children that should be start
    bool[Tid] runChildren; // A list of children
    bool[Tid] failChildren; // An associative array of children that have recently send a fail message
    bool stop;

    void signal(Sig signal) {
        with (Sig) final switch (signal) {
        case STOP:
            stop = true;
            break;
        }
    }

    /// Controls message sent from the children.
    void control(CtrlMsg msg) {
        with (Ctrl) final switch (msg.ctrl) {
        case STARTING:
            debug writeln(msg);
            /* startChildren[msg.tid] = msg.tid; */
            writeln("Is starting: ", startChildren);
            break;

        case ALIVE:
            debug writeln(msg);
            /* if (msg.tid in failChildren) { */
            /*     startChildren.remove(msg.tid); */
            /* } */
            else {
                throw new Exception("%s: never started".format(msg.tid));
            }

            /* if (msg.tid in failChildren) { */
            /*     failChildren.remove(msg.tid); */
            /* } */
            break;

        case FAIL:
            debug writeln(msg);
            /// Add the failing child to the AA of children to restart
            /* failChildren[msg.tid] = msg.tid; */
            break;

        case END:
            debug writeln(msg);
            /* if (msg.tid in failChildren) { */
            /*     Thread.sleep(100.msecs); */
            /*     writeln("Respawning actor"); */
            /*     // Uh respawn the actor, would be easier if we had a proper actor handle instead of a tid */
            /* } */
            break;
        }
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
        setState(Ctrl.FAIL);
        assert(0, "No delegate to deal with message: %s".format(message));
    }

    /**
     * A General actor task function
     *
     * Params:
     *   opts = A list of message handlers similar to @std.concurrency.receive()
     */
    // Would probably be better as a template mixin, then we wouln't create a new scope, which causes some problems
    nothrow void genActorTask(T...)(T opts) {
        try {
            stop = false;

            setState(Ctrl.STARTING); // Tell the owner that you are starting.
            scope (exit) setState(Ctrl.END); // Tell the owner that you have finished.
            setState(Ctrl.ALIVE); // Tell the owner that you running
            while (!stop) {
                receive(
                        opts,
                        &signal,
                        &control,
                        &ownerTerminated,
                        &unknown,
                );
            }
        }
        // If we catch an exception we send it back to owner for them to deal with it.
        catch (Exception e) {
            // FAIL message should be able to carry the exception with it
            // Use tagion taskexception when it part of the tree
            immutable exception = cast(immutable) e;
            assumeWontThrow(ownerTid.prioritySend(exception));
            setState(Ctrl.FAIL);
            stop = true;
        }
    }
}

import std.traits;

/// Checks if the actor is implemented correctly
private template isActor(A) {
    /* template areMembersStatic(A) { */
    /*     static foreach(F; Fields!A) { */
    /*     } */
    /* } */

    template isTaskNothrow(A) {
        alias task = __traits(getMember, A, "task");
        enum isTaskNothrow =
            (functionAttributes!task & FunctionAttribute.nothrow_);
    }

    enum isActor = isTaskNothrow!A;
}


mixin template ActorTask(T...) {
    bool stop = false;
    Ctrl[Tid] childrenState;

    void signal(Sig signal) {
        with (Sig) final switch (signal) {
        case STOP:
            stop = true;
            break;
        }
    }

    /// Controls message sent from the children.
    void control(CtrlMsg msg) {
        with (Ctrl) final switch (msg.ctrl) {
        case STARTING:
            debug writeln(msg);
            /* startChildren[msg.tid] = msg.tid; */
            /* writeln("Is starting: ", startChildren); */
            break;

        case ALIVE:
            debug writeln(msg);
            /* if (msg.tid in failChildren) { */
            /*     startChildren.remove(msg.tid); */
            /* } */
            else {
                throw new Exception("%s: never started".format(msg.tid));
            }

            /* if (msg.tid in failChildren) { */
            /*     failChildren.remove(msg.tid); */
            /* } */
            break;

        case FAIL:
            debug writeln(msg);
            /// Add the failing child to the AA of children to restart
            /* failChildren[msg.tid] = msg.tid; */
            break;

        case END:
            debug writeln(msg);
            /* if (msg.tid in failChildren) { */
            /*     Thread.sleep(100.msecs); */
            /*     writeln("Respawning actor"); */
            /*     // Uh respawn the actor, would be easier if we had a proper actor handle instead of a tid */
            /* } */
            break;
        }
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
        setState(Ctrl.FAIL);
        assert(0, "No delegate to deal with message: %s".format(message));
    }

    nothrow void task() {
        try {

            setState(Ctrl.STARTING); // Tell the owner that you are starting.
            scope (exit) setState(Ctrl.END); // Tell the owner that you have finished.

            foreach(c; children) {
                /* immutable task = cast(immutable) c.task; */
                Tid tid = spawn(&c.task);
                childrenState[tid] = Ctrl.STARTING;
            }
            /* spawn(&a.task); */

            // Should have a timeout incase the don't alive themselves;
            /* while(!childrenState.all(Ctrl.ALIVE)) { */
            /*     CtrlMsg msg = receiveOnly!CtrlMsg; */
            /*     childrenState[msg.tid] = msg.ctrl; */
            /* } */
            writeln("started all the chldren");

            setState(Ctrl.ALIVE); // Tell the owner that you running
            while (!stop) {
                receive(
                        T,
                        &signal,
                        &control,
                        &ownerTerminated,
                        &unknown,
                );
            }
        }
        // If we catch an exception we send it back to owner for them to deal with it.
        catch (Exception e) {
            // FAIL message should be able to carry the exception with it
            // Use tagion taskexception when it part of the tree
            immutable exception = cast(immutable) e;
            assumeWontThrow(ownerTid.prioritySend(exception));
            setState(Ctrl.FAIL);
            stop = true;
        }
    }
}
