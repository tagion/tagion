import actor.common;

import std.concurrency;
import std.stdio;
import std.format;

static class SuperVisor : Actor {
    void task() {
        stop = false;

        setState(Ctrl.STARTING); // Tell the owner that you are starting.
        scope (exit) setState(Ctrl.END); // Tell the owner that you have finished.

        setState(Ctrl.ALIVE); // Tell the owner that you running
        while (!stop) {
            try {
                actorTask();
            }

            // If we catch an exception we send it back to owner for them to deal with it.
            catch (shared(Exception) e) {
                // Preferable FAIL would be able to carry the exception with it
                ownerTid.prioritySend(e);
                setState(Ctrl.FAIL);
                stop = true;
            }
        }
    }
}

static class Logger : Actor {

    void task() {
        actorTask(
                (Msg!"info", string str) {
                    writeln("Info: ", str); 
                    /// something else
                },
                (Msg!"fatal", string str) {
                    writeln("Fatal: ", str);
            },
        );
    }

}

void main() {
    alias logger_task = Logger.task;
    Tid logger = spawn(&logger_task);
    register("logger", logger);

    assert(checkCtrl(Ctrl.STARTING));
    assert(checkCtrl(Ctrl.ALIVE));

    logger.send(Msg!"info"(), "plana");
    logger.send(Msg!"fatal"(), "submarina");
    logger.send(Msg!"info"(), "tuna");
    logger.send(Sig.STOP);
    assert(checkCtrl(Ctrl.END));

}
