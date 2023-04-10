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
import std.meta;

struct AAA {
static:
    void task() {
    writeln("I am the child");
    }
}


struct BBB {
static:
    nothrow void task() {
    assumeWontThrow(writeln("I am the child"));
    }
}


alias TaskPtr = void delegate();

struct TemplateActor {
static:
    Logger logger;
    Counter count;
    alias children = AliasSeq!(logger);

    void message(Msg!"msg", string str) {writeln(str);}
    mixin ActorTask!(&message);
}

class SuperVisor : Actor {
static:

    void task() nothrow {
        setState(Ctrl.STARTING);

        spawnActor!Logger("logger");
        spawnActor!Counter("counter");

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

template ListOf(T) {
    struct List {
        T[] items;
        void add(U)(U item) if (is(T : U)) {
            items ~= cast(T) item;
        }
    }
}
/// Running through flow of top-level actors
void main() {

    writeln(":asaghiuysguyiw");
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

    import std.typecons;
    import std.range;

    /* alias children = Tuple!(Counter, "count", Logger, "logger"); */

    /* /1* pragma(msg, ts); *1/ */
    /* foreach(A; children.Types) { */
    /*     spawn(&A.task); */
    /*     /1* writeln(k,v); *1/ */
    /*     assert(checkCtrl(Ctrl.STARTING)); */
    /*     assert(checkCtrl(Ctrl.ALIVE)); */
    /* } */

    /* spawnActor!SuperVisor("supervisor"); */
    /* assert(checkCtrl(Ctrl.STARTING)); */
    /* assert(checkCtrl(Ctrl.ALIVE)); */

    auto Super = spawnActor!TemplateActor("Super");

    assert(checkCtrl(Ctrl.STARTING));
    assert(checkCtrl(Ctrl.ALIVE));

    Super.send(Sig.STOP);
    assert(checkCtrl(Ctrl.END));
}
