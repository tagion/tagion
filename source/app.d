import actor.common;

import std.concurrency;
import std.stdio;
import std.format;

static class SuperVisor : Actor {
    nothrow void task() {
        actorTask;
    }
}

static class Logger : Actor {

    nothrow void task() {
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
