import tagion.actor.actor;

import std.concurrency;
import std.stdio;
import std.format;

class SuperVisor : Actor {
static:
    /* void task() { */
    /*     actorTask; */
    /* } */
}

alias SuperVisorHandle = ActorHandle!SuperVisor;

class Counter : Actor {
static:
    alias decrease = Msg!"decrease";
    alias increase = Msg!"increase";

    nothrow void task() {
        actorTask(
                &_decrease,
                &_increase,
        );
    }

    int count = 0;

    void _decrease(decrease) {
        count--;
        writeln("Count is: ", count);
    }

    void _increase(increase) {
        count++;
        writeln("Count is: ", count);
    }
}

alias CounterHandle = ActorHandle!Counter;

static class Logger : Actor {
    alias hell = Msg!"hell";
    alias info = Msg!"info";
    alias fatal = Msg!"fatal";

    static void _hell(hell, string str) {
        writeln("Hell: ", str); /// something else
    }

    static void _info(info, string str) {
        writeln("Info: ", str); /// something else
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

    CounterHandle counter = spawnActor!Counter("counter_task");
    assert(checkCtrl(Ctrl.STARTING));
    assert(checkCtrl(Ctrl.ALIVE));

    counter.send(Counter.increase());
    logger.send(Logger.fatal(), "plana");
    counter.send(Counter.decrease());
    logger.send(Logger.hell(), "tuna");
    counter.send(Counter.increase());
    logger.send(Logger.info(), "plana");

    counter.send(Sig.STOP);
    logger.send(Sig.STOP);

    assert(checkCtrl(Ctrl.END));
    assert(checkCtrl(Ctrl.END));

}
