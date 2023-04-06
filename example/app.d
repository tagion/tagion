import tagion.actor.actor;

import std.concurrency;
import std.stdio;
import std.format;

static class SuperVisor : Actor {
    nothrow void task() {
        actorTask;
    }
}

alias SuperVisorHandle = ActorHandle!SuperVisor;

static class Logger : Actor {
    alias hell = Msg!"hell";
    alias info = Msg!"info";
    alias fatal = Msg!"fatal";

    static void _hell(hell, string str) {
        writeln("Hell: ", str);/// something else
    }

    static void _info(info, string str) {
        writeln("Info: ", str);/// something else
    }

    static void _fatal(fatal, string str) {
        writeln("Fatal: ", str);
    }

    nothrow void task() {
        actorTask(
            &_info,
            &_hell,
            &_fatal,
        );
    }

}

alias LoggerHandle = ActorHandle!Logger;

void main() {

    LoggerHandle logger = spawnActor!Logger("logger_task");

    assert(checkCtrl(Ctrl.STARTING));
    assert(checkCtrl(Ctrl.ALIVE));

    logger.send(Logger.fatal(), "plana");
    logger.send(Logger.info(), "plana");
    logger.send(Logger.fatal(), "tuna");
    logger.send(Sig.STOP);
    assert(checkCtrl(Ctrl.END));

}
