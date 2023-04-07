/**
 * Examples for the actor library
 */


module tagion.actor.example;

import tagion.actor.actor;

import std.concurrency;
import std.stdio;
import std.format;
import std.typecons;
import std.exception;

class SuperVisor : Actor {
static:
   void task() nothrow {
        assumeWontThrow(spawnActor!Logger("log"));

        actorTask;
    }
}

alias SuperVisorHandle = ActorHandle!SuperVisor;

/**
 * An actor that keeps counter
 * Which can be modifyed by sending it an increase or decrease message
 */
class Counter : Actor {
static:
    void task() nothrow {
        actorTask(
                &_decrease,
                &_increase,
        );
    }

    alias decrease = Msg!"decrease";
    alias increase = Msg!"increase";


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

/// The handler type to our Counter
alias CounterHandle = ActorHandle!Counter;

/**
 * An actor which we can send log levels message too
 */
class Logger : Actor {
static:
    alias hell = Msg!"hell";
    alias info = Msg!"info";
    alias fatal = Msg!"fatal";

    void _hell(hell, string str) {
        writeln("Hell: ", str); /// something else
    }

    void _info(info, string str) {
        writeln("Info: ", str); /// something else
    }

    void _fatal(fatal, string str) {
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

/// The handler type to our Logger
alias LoggerHandle = ActorHandle!Logger;

/// Running through flow of top-level actors
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

    /* spawnActor!SuperVisor("super"); */
    /* assert(checkCtrl(Ctrl.STARTING)); */
    /* assert(checkCtrl(Ctrl.ALIVE)); */
    /* logger.send(Sig.STOP); */
    /* assert(checkCtrl(Ctrl.END)); */
}
