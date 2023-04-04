module actor.common;

import std.concurrency;
import std.stdio;
import std.format : format;
import std.typecons;

// State messages send to the supervisor
enum Control {
    STARTING, // The actors is lively
    ALIVE, /// Send to the ownerTid when the task has been started
    FAIL, /// This if a something failed other than an exception
    END, /// Send for the child to the ownerTid when the task ends
}

// Signals send from the supervisor to the direct children
enum Signal {
    STOP,
}

/// Control message sent to a supervisor 
/// contains the Tid of the actor which send it and the state
alias CtrlMsg = Tuple!(Tid, Control);

bool checkCtrl(Control msg) {
    // Never use receiveOnly
    CtrlMsg r = receiveOnly!(CtrlMsg);
    debug writeln(r);
    return r[1] is msg;
}

// Delegate for dealing with exceptions sent from children
void exceptionHandler(Exception e) {
    // logger.send(fatal, e);
    writeln(e);
}

Nullable!Tid maybeOwnerTid() {
    // tid is "null"
    Nullable!Tid tid;
    try {
        // Tid is asigned
        tid = ownerTid;
    }
    catch (TidMissingException) {
    }
    return tid;
}

/// Send to the owner if there is one
void sendOwner(T...)(T vals) {
    if (!maybeOwnerTid.isNull) {
        send(maybeOwnerTid.get, vals);
    }
    // Otherwise writr a message to the logger instead,
    // Otherwise just write it to stdout;
    else {
        write("No owner, writing message to stdout instead: ");
        writeln(vals);
    }
}

/// send your state to your owner
void setState(Control ctrl) {
    if (!maybeOwnerTid.isNull) {
        prioritySend(maybeOwnerTid.get, thisTid, ctrl);
    }
    else {
        write("No owner, writing message to stdout instead: ");
        writeln(ctrl);
    }
}

version (none) struct ActorHandle {
    Tid tid;
    string taskName;
    // Tid Owner?
}

import std.algorithm.iteration;

Tid[] spawnChildren(F)(F[] fns) /* if ( */
/*     fn.each(isSpawnable(f)); } */
/*     ) { */ {
    Tid[] tids;
    foreach (f; fns) {
        // Starting and checking the children sequentially :(
        tids ~= spawn(f);
        assert(checkCtrl(Control.STARTING));
        assert(checkCtrl(Control.ALIVE));
    }
    return tids;
}

static class Actor {
    static Tid[] children;
    static string task_name;
    /// Static ActorHandle[] children;
    static bool stop;

    static void signal(Signal s) {
        with (Signal) final switch (s) {
        case STOP:
            stop = true;
            break;
        }
    }
    /// Controls message sent from the children.
    void control(CtrlMsg msg) {
    }

    static void ownerTerminated(OwnerTerminated _e) {
        writefln("%s, Owner stopped... nothing to life for... stoping self", thisTid);
        stop = true;
    }
    // Default
    static void unknown(Variant message) {
        // For unkown messages we assert, and send a fail message to the owner
        // so we don't accidentally fill up our messagebox with garbage
        setState(Control.FAIL);
        assert(0, "No delegate to deal with message: %s".format(message));
    }

    // We need to be certain that anything the task inherits from outside scope
    // is maintained as a copy and not a reference.
    void task(A...)(A args);
    /// Structure
    /* while(!stop)
        receive(
            Msgs...
            &signal,
            &control,
            &unkown,
        ))
    */
}
