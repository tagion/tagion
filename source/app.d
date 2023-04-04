import std.concurrency;
import std.stdio;
import std.format: format;
import std.typecons;

// State messages send to the supervisor
enum Control {
    STARTING, // The actors is lively
    ALIVE, /// Send to the ownerTid when the task has been started
    FAIL, /// This if a something failed other than an exception
    END, /// Send for the child to the ownerTid when the task ends
}

/// Control message sent to a supervisor 
/// contains the Tid of the actor which send it and the state
alias CtrlMsg = Tuple!(Tid, Control);

bool checkCtrl(Control msg) {
    CtrlMsg r = receiveOnly!(CtrlMsg);
    debug writeln(r);
    return r[1] is msg;
}

version(none)
struct ActorHandle {
    Tid tid;
    string taskName;
    // Tid Owner?
}

/// Just spawn a single actor and make sure it doesn't fail for some duration
void restartIffailed(F, T...)(F fn, T args)
if (isSpawnable!(F, T))
{
    static assert(!hasLocalAliasing!(T), "Aliases to mutable thread-local data not allowed.");
    Tid childtid = _spawn(false, fn, args);
    checkCtrl(Control.STARTING);
    checkCtrl(Control.ALIVE);
}

// Signals send from the supervisor to the direct children
enum Signal {
    STOP,
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
    catch(TidMissingException) {
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


struct M(int name) {}

import std.typecons;
struct Logger {
    enum Msg{
        info = 0,
        fatal,
    }

    void task() {
        bool stop = false;

        setState(Control.STARTING); // Tell the owner that you are starting.
        setState(Control.ALIVE); // Tell the owner that you running
        scope(exit) setState(Control.END); // Tell the owner that you have finished.

        while(!stop) {
            try {
                receive(
                /* &msgDelegate, */
                (M!0, string str) { writeln("Info: ", str); },
                (M!1, string str) { writeln("Fatal: ", str); },
                /* &exceptionHandler, */

                (Signal s) {
                    with(Signal) final switch(s) {
                        case STOP:
                        stop = true;
                        break;
                    }
                },
                (OwnerTerminated _e) {
                    writefln("%s, Owner stopped... nothing to life for... stoping self", thisTid);
                    stop = true;
                },
                // Default
                (Variant message) {
                        // For unkown messages we assert, and send a fail message to the owner
                        // so we don't accidentally fill up our messagebox with garbage
                        setState(Control.FAIL);
                        assert(0, "No delegate to deal with message: %s".format(message));
                    }
                );
            }
            // If we catch an exception we send it back to owner for them to deal with it.
            catch (shared(Exception) e) {
                // Preferable FAIL would be able to carry the exception with it
                ownerTid.prioritySend(e);
                setState(Control.FAIL);
                stop = true;
            }
        }
    }
}


void main() {
    auto logger_proto = Logger();
    alias logger_task = logger_proto.task;
    Tid logger = spawn(&logger_task);
    register("logger", logger);

    assert(checkCtrl(Control.STARTING));
    assert(checkCtrl(Control.ALIVE));

    logger.send(M!0(), "hello");
    logger.send(M!0(), "momma");
    logger.send(Signal.STOP);
    assert(checkCtrl(Control.END));

    logger.send(M!1(), "momma");
}
