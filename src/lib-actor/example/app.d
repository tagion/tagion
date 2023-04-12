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

struct SuperVisor {
static:
    Logger logger;
    Counter count;
    alias children = AliasSeq!(logger, count);

    void message(Msg!"msg", string str) {
        writeln(str);
    }

    mixin Actor!(&message);
}

alias SuperVisorHandle = ActorHandle!SuperVisor;

/**
 * An actor that keeps counter
 * Which can be modifyed by sending it an increase or decrease message
 */
struct Counter {
static:
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
    /* mixin ActorTask!(&_increase, _decrease); */
    mixin Actor;
}

/// The handler type to our Counter
alias CounterHandle = ActorHandle!Counter;

/**
 * An actor which we can send log levels message too
 */
struct Logger {
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

    mixin Actor;
    /* mixin ActorTask!(&_fatal, &_info, &_hell); */

}

/// The handler type to our Logger alias LoggerHandle = ActorHandle!Logger;

template ListOf(T) {
    struct List {
        T[] items;
        void add(U)(U item) if (is(T : U)) {
            items ~= cast(T) item;
        }
    }
}
/// Running through flow of top-level actors
void _main() {

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

    auto Super = spawnActor!SuperVisor("Super");
    /* auto bbb = spawnActor!BBB("bbb"); */

    assert(checkCtrl(Ctrl.STARTING));
    assert(checkCtrl(Ctrl.ALIVE));
    Super.send(Msg!"msg"(), "hello");
    Super.send(Msg!"msg"(), "hello");
    Super.send(Msg!"msg"(), "hello");

    /* Super.send(Sig.STOP); */
    /* assert(checkCtrl(Ctrl.END)); */
    /* while(true) { */
    /* } */
}
