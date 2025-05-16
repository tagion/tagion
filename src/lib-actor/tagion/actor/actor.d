/// Actor framework implementation
/// Examples: [tagion.testbench.services]
module tagion.actor.actor;

@safe:

import core.exception : AssertError;
import core.thread;
import core.time;

import std.typecons;
import std.exception;
import std.format : format;
import std.meta;
import std.traits;
import std.typecons;
import std.variant : Variant;

import tagion.actor.exceptions;
import tagion.hibon.HiBONRecord;
import tagion.logger;
import tagion.utils.Result;
import concurrency = tagion.utils.pretend_safe_concurrency;
import tagion.utils.pretend_safe_concurrency;
import tagion.actor.exceptions;
import tagion.hibon.HiBONRecord;

/**
 * Message "Atom" type
 * Examples:
 * ---
 * // As a type
 * Msg!"hi";
 * // As a value
 * Msg!"hi"();
 * ---
 */
struct Msg(string name) {
}

private struct ActorInfo {
    Ctrl[string] childrenState;
    bool stop;

    uint msgs_sent;
    uint msgs_received;

    @property @safe
    bool task_name(string name) nothrow const {
        return log.task_name(name);
    }

    @property @safe
    string task_name() const nothrow {
        return log.task_name;
    }
}

static ActorInfo thisActor;

struct ActorInfoRecord {
    string task_name;
    uint msgs_sent;
    uint msgs_received;
    Ctrl[string] childrenState;

    mixin HiBONRecord!(q{
        this(ActorInfo info) {
            this.task_name = info.task_name;
            this.msgs_sent = info.msgs_sent;
            this.msgs_received = info.msgs_received;
            this.childrenState = info.childrenState;
        }
    });
}

///
unittest {
    enum dummy_name = "dummy_name";
    scope (exit) {
        unregister(dummy_name);
    }
    assert(thisActor.task_name = dummy_name, "setting name failed");
    assert(thisActor.task_name = dummy_name, "setting name seconds time did not fallthrough");
    assert(thisActor.task_name == dummy_name, "name was not the same as we set");
    concurrency.spawn(() {
        assert(!(thisActor.task_name = dummy_name), "Should not be able to set the same task name in another tid");
    });
    assert(locate(thisActor.task_name) is thisTid, "Name not registered");
}

/* 
 * Reguest type
 * Will generate a random id if the ID type is a number
 */
struct Request(string name, ID = uint) {
    Msg!name msg;
    ID id;
    Tid tid;

    static Request opCall() @safe {
        import tagion.utils.Random;
        static assert(isNumeric!ID, "Can not auto generate an id for non numeric ID type");
        return typeof(this).opCall(generateId!(Unqual!ID));
    }

    static Request opCall(ID id) @safe {
        Request!(name, ID) r = { Msg!name(), id, thisTid};
        return r;
    }

    alias Response = .Response!(name, ID);

    /// Send back some data to the task who sent the request
    void respond(Args...)(Args args) {
        auto res = Response(msg, id);
        this.tid.send(res, args);
    }
}

/// 
struct Response(string name, ID = uint) {
    Msg!name msg;
    ID id;
}

///
@safe
unittest {
    thisActor.task_name = "req_resp";
    scope (exit) {
        unregister("req_resp");
        thisActor.task_name = "";
    }
    alias Some_req = Request!"some_req";
    void some_responder(Some_req req) {
        req.respond("hello");
    }

    auto created_req = Some_req();
    some_responder(created_req);
    int received = receiveTimeout(Duration.zero, (Some_req.Response res, string _) {
        assert(created_req.msg == res.msg, "request msg were not the same");
        assert(created_req.id == res.id, "request id were not the same");
    });
    assert(received, "never received response");
}

// State messages send to the supervisor
enum Ctrl {
    UNKNOWN, // Unkwnown state
    STARTING, // The actors is starting
    ALIVE, /// The actor is running
    END, /// The actor is stopping
}

// Signals send from the supervisor to the direct children
enum Sig {
    STOP,
}

/// Control message sent to a supervisor
/// contains the Tid of the actor which send it and the state
alias CtrlMsg = Tuple!(string, "task_name", Ctrl, "ctrl");

bool statusChildren(Ctrl ctrl) @safe nothrow {
    foreach (val; thisActor.childrenState.byValue) {
        if (val != ctrl) {
            return false;
        }
    }
    return true;
}

/* 
 * Waif for the spawned child Actors of this thread to be in Ctrl state.
 * If it an Ctrl.END state it will free the children.
 * Returns: true if all of the get in Ctrl state before the timeout
 */
bool waitforChildren(Ctrl state, Duration timeout = 1.seconds) @safe nothrow {
    const begin_time = MonoTime.currTime;
    try {
        while (!statusChildren(state) && MonoTime.currTime - begin_time <= timeout) {
            if (thisActor.stop && state !is Ctrl.END) {
                return false;
            }
            receiveTimeout(
                timeout / thisActor.childrenState.length,
                defaultFailhandler,
                &control,
                &signal,
                &ownerTerminated

            );
        }
        log("%s", thisActor.childrenState);
        if (state is Ctrl.END) {
            destroy(thisActor.childrenState);
        }
        return statusChildren(state);
    }
    catch (Exception e) {
        log.fatal("Error when waiting for children status\n%s", e);
        return false;
    }
}

unittest {
    enum task_name = "child_task";
    assert(waitforChildren(Ctrl.ALIVE, Duration.min), "Waiting for no spawned tid, should always be true");
    thisActor.childrenState[task_name] = Ctrl.STARTING;
    assert(!waitforChildren(Ctrl.ALIVE, Duration.min), "should've timed out");
    thisActor.childrenState[task_name] = Ctrl.ALIVE;
    assert(waitforChildren(Ctrl.ALIVE, Duration.min));
    thisActor.childrenState[task_name] = Ctrl.END;
    assert(waitforChildren(Ctrl.END));
    assert(thisActor.childrenState.length == 0, "childrenState should be cleaned up when checked that all of them have ended");
}

/// Checks if a type has the required members to be an actor
enum bool isActor(A) = hasMember!(A, "task") && isCallable!(A.task) && isSafe!(A.task);

enum bool isFailHandler(F)
    = is(F : void function(TaskFailure))
    || is(F : void delegate(TaskFailure));

/// Stolen from std.concurrency;
template isSpawnable(F, T...) {
    template isParamsImplicitlyConvertible(F1, F2, int i = 0) {
        alias param1 = Parameters!F1;
        alias param2 = Parameters!F2;
        static if (param1.length != param2.length)
            enum isParamsImplicitlyConvertible = false;
        else static if (param1.length == i)
            enum isParamsImplicitlyConvertible = true;
        else static if (isImplicitlyConvertible!(param2[i], param1[i]))
            enum isParamsImplicitlyConvertible = isParamsImplicitlyConvertible!(F1,
                    F2, i + 1);
        else
            enum isParamsImplicitlyConvertible = false;
    }

    enum isSpawnable = isCallable!F && is(ReturnType!F : void)
        && isParamsImplicitlyConvertible!(F, void function(T))
        && (isFunctionPointer!F || !hasUnsharedAliasing!F);
}

/**
 * A "reference" to an actor that may or may not be spawned, we will never know
 */
struct ActorHandle {
    /// the name of the possibly running task
    string task_name;
    private Tid _tid;
    /// the tid of the spawned task
    Tid tid() {
        _tid = concurrency.locate(task_name);
        return _tid;
    }

    bool isActive() {
        return tid !is Tid.init;
    }

    // Get the status of the task, asserts if the calling task did not spawn it
    Ctrl state() nothrow {
        if ((task_name in thisActor.childrenState) !is null) {
            return thisActor.childrenState[task_name];
        }
        return Ctrl.UNKNOWN;
    }

    /// Send a message to this task
    void send(T...)(T args) @trusted {
        try {
            concurrency.send(_tid, args);
        }
        catch (AssertError _) {
            concurrency.send(tid, args).collectException!AssertError;
        }
        thisActor.msgs_sent++;
    }
    /// Send a message to this task
    void prioritySend(T...)(T args) @trusted {
        try {
            concurrency.prioritySend(_tid, args);
        }
        catch (AssertError _) {
            concurrency.prioritySend(tid, args).collectException!AssertError;
        }
        thisActor.msgs_sent++;
    }
}

ActorHandle spawn(A, Args...)(immutable(A) actor, string name, Args args) @safe nothrow
if (isActor!A && isSpawnable!(typeof(A.task), Args)) {
    try {
        Tid tid;
        tid = concurrency.spawn((immutable(A) _actor, string name, Args args) @trusted nothrow{
            thisActor.task_name = name;
            thisActor.stop = false;
            A actor = cast(A) _actor;
            setState(Ctrl.STARTING); // Tell the owner that you are starting.
            try {
                actor.task(args);

                // If the actor forgets to kill it's children we'll do it anyway
                if (!statusChildren(Ctrl.END)) {
                    foreach (child_task_name, ctrl; thisActor.childrenState) {
                        if (ctrl is Ctrl.ALIVE) {
                            ActorHandle(child_task_name).send(Sig.STOP);
                        }
                    }
                    waitforChildren(Ctrl.END);
                }

            }
            catch (Exception t) {
                fail(t);
            } // This is bad but, We catch assert per thread because there is no message otherwise, when running multithreaded
            catch (AssertError e) {
                import tagion.GlobalSignals;

                log.fatal(e);
                stopsignal.setIfInitialized;
            }
            end();
        }, actor, name, args);
        thisActor.childrenState[name] = Ctrl.UNKNOWN;
        log("spawning %s", name);
        tid.setMaxMailboxSize(int.max, OnCrowding.throwException);
        return ActorHandle(name, tid);
    }
    catch (Exception e) {
        assert(0, format("Exception: %s", e.msg));
    }
}

ActorHandle _spawn(A, Args...)(string name, Args args) @safe nothrow
if (isActor!A) {
    try {
        static if(!__traits(compiles, A(args))) {
            A(args); // error constructor A() cannot be called with Args
        }

        Tid tid;
        tid = concurrency.spawn((string name, Args args) @trusted nothrow{
            thisActor.task_name = name;
            thisActor.stop = false;
            try {
                A actor = A(args);
                setState(Ctrl.STARTING); // Tell the owner that you are starting.
                actor.task();
                // If the actor forgets to kill it's children we'll do it anyway
                if (!statusChildren(Ctrl.END)) {
                    foreach (child_task_name, ctrl; thisActor.childrenState) {
                        if (ctrl is Ctrl.ALIVE) {
                            ActorHandle(child_task_name).prioritySend(Sig.STOP);
                        }
                    }
                    /* waitforChildren(Ctrl.END); */
                }
            }
            catch (Exception t) {
                fail(t);
            } // This is bad but, We catch assert per thread because there is no message otherwise, when running multithreaded
            catch (AssertError e) {
                import tagion.GlobalSignals;

                log.fatal(e);
                stopsignal.setIfInitialized;
            }
            end();
        }, name, args);
        thisActor.childrenState[name] = Ctrl.UNKNOWN;
        log("spawning %s", name);
        tid.setMaxMailboxSize(int.max, OnCrowding.throwException);
        return ActorHandle(name, tid);
    }
    catch (Exception e) {
        log.fatal(e);
        assert(0, format("Exception: %s", e.msg));
    }
}

ActorHandle spawn(A, Args...)(string name, Args args) @safe nothrow
if (isActor!A) {
    immutable A actor;
    return spawn(actor, name, args);
}


/// Send to the owner if there is one
void sendOwner(T...)(T vals) @safe {
    try {
        concurrency.send(ownerTid, vals);
    }
    catch(Exception) {
        log.error("No owner tried to send a message to it");
        log.error("%s", tuple(vals));
    }
}

static Topic taskfailure = Topic("taskfailure");

/** 
 * Send a TaskFailure up to the owner
 * Silently fails if there is no owner
 * Does NOT exit regular control flow
*/
void fail(Throwable t) nothrow {
    try {
        debug (actor) {
            log(t);
        }
        immutable tf = TaskFailure(thisActor.task_name, t);
        log.event(taskfailure, "taskfailure", tf);
        ownerTid.prioritySend(tf);
    }
    catch (Exception e) {
        log.fatal("Failed to deliver TaskFailure: \n
                %s\n\n
                Because:\n
                %s", t, e);
        log.fatal("Stopping because we failed to deliver a TaskFailure to the supervisor");
        thisActor.stop = true;
    }
}

/// send your state to your owner
void setState(Ctrl ctrl) @safe nothrow {
    try {
        log("setting state to %s", ctrl);
        assert(thisActor.task_name !is string.init, "Can not set the state for a task with no name");
        ownerTid.prioritySend(CtrlMsg(thisActor.task_name, ctrl));
    }
    catch (TidMissingException e) {
        log.error("Failed to set state %s", e.message);
    }
    catch (Exception e) {
        log.error("Failed to set state");
        log.fatal(e);
    }
}

/// Cleanup and notify the supervisor that you have ended
void end() @trusted nothrow {
    thisActor.stop = true;
    assumeWontThrow(ThreadInfo.thisInfo.cleanup);
    setState(Ctrl.END);
}

/* 
 * Params:
 *   task_name = the name of the task
 *   args = a list of message handlers for the task
 *   the first message handler may be a failHandler to deal with TaskFailure from other tasks
 */
void run(Args...)(Args args) @safe nothrow
if (allSatisfy!(isSafe, Args)) {
    // Check if a failHandler was passed as an arg
    static if (args.length >= 1 && isFailHandler!(typeof(args[$ - 1]))) {
        enum failhandler = () @safe {}; /// Use the fail handler passed through `args`
    }
    else {
        enum failhandler = defaultFailhandler;
    }

    scope (failure) {
        setState(Ctrl.END);
    }

    if(thisActor.stop) {
        return;
    }

    setState(Ctrl.ALIVE); // Tell the owner that you are running
    while (!thisActor.stop) {
        try {
            receive(
                args, // The message handlers you pass to your Actor template
                failhandler,
                default_handlers.expand,
            );
            thisActor.msgs_received++;
        }
        catch (MailboxFull t) {
            fail(t);
            thisActor.stop = true;
        }
        catch (Exception t) {
            fail(t);
        }
    }
}

/** 
 * 
 * Params:
 *   duration = the duration for the timeout
 *   timeout = delegate function to call
 *   args = normal message handlers for the task
 *   the first message handler may be a failHandler to deal with TaskFailure from other tasks
 */
void runTimeout(Args...)(Duration duration, void delegate() @safe timeout, Args args) nothrow
        if (allSatisfy!(isSafe, Args)) {
    // Check if a failHandler was passed as an arg
    static if (args.length >= 1 && isFailHandler!(typeof(args[$ - 1]))) {
        enum failhandler = () @safe {}; /// Use the fail handler passed through `args`
    }
    else {
        enum failhandler = defaultFailhandler;
    }

    scope (failure) {
        setState(Ctrl.END);
    }

    if(thisActor.stop) {
        return;
    }

    setState(Ctrl.ALIVE); // Tell the owner that you are running
    while (!thisActor.stop) {
        try {
            const message = receiveTimeout(
                duration,
                args, // The message handlers you pass to your Actor template
                failhandler,
                default_handlers.expand,
            );
            if (!message) {
                timeout();
            }
            else {
                thisActor.msgs_received++;
            }
        }
        catch (MailboxFull t) {
            fail(t);
            thisActor.stop = true;
        }
        catch (Exception t) {
            fail(t);
        }
    }
}

enum defaultFailhandler = (TaskFailure tf) @safe nothrow {
    try {
        ownerTid.prioritySend(tf);
    }
    catch(TidMissingException e) {
        log.error("%s", tf);
    }
    catch(Exception e) {
        log.fatal(e);
    }
};

void signal(Sig signal) @safe {
    log.trace("Received stop signal");
    with (Sig) final switch (signal) {
    case STOP:
        thisActor.stop = true;
        break;
    }
}

/// Controls message sent from the children.
void control(CtrlMsg msg) @safe {
    thisActor.childrenState[msg.task_name] = msg.ctrl;
}

/// Stops the actor if the supervisor stops
void ownerTerminated(OwnerTerminated) @safe {
    log.trace("%s, Owner stopped... nothing to life for... stopping self", thisTid);
    thisActor.stop = true;
}

/**
 * The default message handler, if it's an unknown messages it will send a FAIL to the owner.
 * Params:
 *   message = literally any message
 */
void unknown(Variant message) @trusted {
    throw new UnknownMessage("No delegate to deal with message: %s".format(message));
}

alias GetActorInfo = Request!"GetActorInfo";
void getActorInfo(GetActorInfo req) {
    req.respond(ActorInfoRecord(thisActor).toDoc);
}

auto default_handlers = tuple(
    &signal,
    &control,
    &getActorInfo,
    &ownerTerminated,
    &unknown,
);
