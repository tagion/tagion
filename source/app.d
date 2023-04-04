import actor.common;

import std.concurrency;
import std.stdio;
import std.format;

struct M(int name) {}

static class Logger : Actor {

    void task() {
        stop = false;

        setState(Control.STARTING); // Tell the owner that you are starting.
        setState(Control.ALIVE); // Tell the owner that you running
        scope (exit) setState(Control.END); // Tell the owner that you have finished.

        /* while (!stop) { */
            try {
                receive(
                        (M!0, string str) { writeln("Info: ", str); },
                        (M!1, string str) { writeln("Fatal: ", str); },

                        &signal,
                        &control,
                        &ownerTerminated,
                        &unknown,
                );
            }
            // If we catch an exception we send it back to owner for them to deal with it.
            catch (shared(Exception) e) {
                // Preferable FAIL would be able to carry the exception with it
                ownerTid.prioritySend(e);
                setState(Control.FAIL);
                stop = true;
            }
        /* } */
    }

}

void main() {
    alias logger_task = Logger.task;
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
