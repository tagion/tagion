import std.concurrency;
import std.stdio;
import std.format: format;
import std.typecons;

static string not_impl() {
    return format("Not implemeted %s(%s)", __FILE__, __LINE__);
}

// Delegate for dealing with exceptions sent from children
void exceptionHandler(Exception e) {
    // logger.send(fatal, e);
    writeln(e);
}

// proto messages for actors
enum Control {
    LIVE, /// Send to the ownerTid when the task has been started
    STOP, /// Send when the child task to stop task
    FAIL, /// This if a something failed other than an exception
    END, /// Send for the child to the ownerTid when the task ends
}

// base implementationm for actor messages.
void controlFlow(Control msg) {
    final switch(msg) {
        case Control.LIVE:
            assert(0, not_impl);
        case Control.STOP:
            assert(0, not_impl);
        case Control.FAIL:
            assert(0, not_impl);
        case Control.END :
            assert(0, not_impl);
    }
}

import std.typecons;
struct Logger {
    enum Msg {
        info,
        fatal,
    }

    void msgDelegate(Msg msg) {
        final switch(msg) {
            with(Msg) {
            case info:
                writeln("info: ", args);
                break;
            case fatal:
                writeln("fatal: ", args);
                break;
            }
        }
    }

    void task() {
        bool stop = false;

        ownerTid.send(Control.LIVE); // Tell the owner that you have started.
        scope(exit) ownerTid.send(Control.END); // Tell the owner that you have finished.

        while(!stop) {
            try {
                receive(
                &msgDelegate,
                &exceptionHandler,

                // Default
                (Variant message) {
                        // For unkown messages we assert, 
                        // basically so we don't accidentally fill up our messagebox with garbage
                        assert(0, "No delegate to deal with message: %s".format(message));
                    }
                );
            }
            catch (OwnerTerminated e) {
                writeln("Owner stopped... nothing to life for... stoping self");
                stop = true;
            }
            // If we catch an exception we send it back to supervisor for them to deal with it.
            catch (shared(Exception) e) {
                ownerTid.send(e);
                stop = true;
            }
        }
    }
}

struct MyActor {
    enum Msg {
        DosomeTask,
    }

    void task() {
        receive((Msg msg) {
            final switch(msg) {
                case Msg.DosomeTask:
                    assert(0, not_impl);
            }
        },
        &controlFlow,
        );
    }
}
// assert to check that this is implemented properly

struct Supervisor {

    // The primary off messages that an Supervisor takes in extension of the control messages
    enum Msg {
        HEALTH,
        NONE,
    }

    void msgDelegate(Msg msg) {
        final switch(msg) {
        case Msg.HEALTH:
            assert(0, not_impl);
        case Msg.NONE:
            assert(0, not_impl);
        }
    }

    void task() {
        bool stop = false;

        ownerTid.send(Control.LIVE); // Tell the owner that you have started.
        scope(exit) ownerTid.send(Control.END); // Tell the owner that you have finished.

        while(!stop) {
            try {
                receive(
                    &msgDelegate,
                    &exceptionHandler,
                    /* &controlFlow, */

                    // Default
                    (Variant message) {
                        // For unkown messages we assert, 
                        // basically so we don't accidentally fill up our messagebox with garbage
                        assert(0, "No delegate to deal with message: %s".format(message));
                    }
                );
            }
            catch (OwnerTerminated e) {
                writeln("Owner stopped... nothing to life for... stoping self");
                stop = true;
            }
            // If we catch an exception we send it back to supervisor for them to deal with it.
            catch (shared(Exception) e) {
                ownerTid.send(e);
                stop = true;
            }
        }
    }
}

void main() {
    auto logger_proto = Logger();
    alias logger_task = logger_proto.task;
    Tid logger = spawn(&logger_task);

    logger.send(Logger.Msg.info, "hello", "hello");
    logger.send(Logger.Msg.info, "momma");
    logger.send(Logger.Msg.fatal, "momma");

    /* auto my_super = Supervisor(); */
    /* alias my_super_fac = my_super.task; */
    /* spawn(&my_super_fac); */
}
