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

    /* static alias ta = Logger.task; */
    /* const void function()[string] children = [ */
    /*     "logger" : &ta, */
    /*     /1* "counter" : &(Counter.task), *1/ */
    /* ]; */
static:

    void task() nothrow {

        genActorTask;
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
        genActorTask(
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
        genActorTask(
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

    /* LoggerHandle logger = spawnActor!Logger("logger_task"); */
    /* assert(checkCtrl(Ctrl.STARTING)); */
    /* assert(checkCtrl(Ctrl.ALIVE)); */

    /* CounterHandle counter = spawnActor!Counter("counter_task"); */
    /* assert(checkCtrl(Ctrl.STARTING)); */
    /* assert(checkCtrl(Ctrl.ALIVE)); */

    /* counter.send(Counter.increase()); */
    /* logger.send(Logger.fatal(), "plana"); */
    /* counter.send(Counter.decrease()); */
    /* logger.send(Logger.hell(), "tuna"); */
    /* counter.send(Counter.increase()); */
    /* logger.send(Logger.info(), "plana"); */

    /* counter.send(Sig.STOP); */
    /* logger.send(Sig.STOP); */

    /* assert(checkCtrl(Ctrl.END)); */
    /* assert(checkCtrl(Ctrl.END)); */

    /* spawnActor!SuperVisor("super"); */
    /* assert(checkCtrl(Ctrl.STARTING)); */
    /* assert(checkCtrl(Ctrl.ALIVE)); */
    /* logger.send(Sig.STOP); */
    /* assert(checkCtrl(Ctrl.END)); */
    /* import std.typecons; */

    import std.meta;

    // AA may cause GC allocation, however static initialisation should be possible in the future
    void function()[string] tasks = [
        "logger": &Logger.task,
        "counter": &Counter.task,
    ];

    foreach (i, A; tasks) {
        spawn(A);
        assert(checkCtrl(Ctrl.STARTING));
        assert(checkCtrl(Ctrl.ALIVE));
    }

    // pretty much the same as before
    immutable nothrow void delegate()[string] tasks2 = [
        "logger": delegate { Logger.task(); },
        "counter": delegate { Counter.task(); },
    ];

    Actor[string] objects = [
        "logger": new Logger(), // Unnecesarry gc allocation
        "counter": new Counter() // Unnecesarry gc allocation
    ];

    // Compile time only, no additional allocation
    alias Act = AliasSeq!(Logger, Counter); //

    version(none)
    foreach (i, A; Act) {
        spawnActor!A(format("%s", i));
        assert(checkCtrl(Ctrl.STARTING));
        assert(checkCtrl(Ctrl.ALIVE));
    }

    foreach (i, A; Act) {
    }

    pragma(msg, typeof(["log": &Logger.task, "count": &Counter.task]));
    alias task = Logger.task;
    pragma(msg, typeof(&task));
}
