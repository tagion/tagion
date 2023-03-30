module tagion.testbench.services.actor_supervisor;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import core.time;
import core.thread;
import concurrency = std.concurrency;
import std.format : format;
import tagion.actor.Actor;

debug import std.stdio;

alias thisInfo = concurrency.ThreadInfo.thisInfo;
import core.time;

receiveOnlyRet!(T) receiveOnlyTimeout(Duration timeout, T...)()
in {
    assert(thisInfo.ident.mbox !is null,
            "Cannot receive a message until a thread was spawned or thisTid was passed to a running thread.");
}
do {
    import std.format : format;
    import std.meta : allSatisfy;
    import std.typecons : Tuple;

    Tuple!(T) ret;

    thisInfo.ident.mbox.get(timeout, (T val) {
        static if (T.length) {
            static if (allSatisfy!(isAssignable, T)) {
                ret.field = val;
            }
            else {
                import core.lifetime : emplace;

                emplace(&ret, val);
            }
        }
    },
            (LinkTerminated e) { throw e; },
            (OwnerTerminated e) { throw e; },
            (Variant val) {
        static if (T.length > 1)
            string exp = T.stringof;
        else
            string exp = T[0].stringof;

        throw new MessageMismatch(
            format("Unexpected message type: expected '%s', got '%s'", exp, val.type.toString()));
    });
    check(ret !is Tuple!(T).init, format("Timed out before receiving message of type %s", T));
    static if (T.length == 1)
        return ret[0];
    else
        return ret;
}

enum feature = Feature(
            "Actor supervisor test",
            ["This feature should check the supervisor fail and restart"]);

alias FeatureContext = Tuple!(
        SupervisorWithFailingChild, "SupervisorWithFailingChild",
        FeatureGroup*, "result"
);

enum sleep_time = 100.msecs;

/// Child Actor
struct SetUpForFailure {

    @method void exceptionalMethod(int _i) {
        debug writeln("child is failing");
        fail(new Exception("Child: I am a failure"));
    }

    @task void run() {
        alive; // Actor is now alive

        /* Thread.sleep(300.msecs); */
        /* fail(Exception("Child: i am a failure")); */
        /* throw new Exception("Child: I am a failure"); */
        while (!stop) {
            receiveTimeout(100.msecs);
        }
    }

    mixin TaskActor; /// Turns the struct into an Actor
}

static assert(isActor!SetUpForFailure);

/// Supervisor Actor
struct SetUpForDissapointment {

    ActorHandle!SetUpForFailure child_handle;

    @method void isChildRunning(string task_name) {
        Thread.sleep(sleep_time);
        sendSupervisor(isRunning(task_name));
    }

    @task void run() {
        auto actor_factory = actor!SetUpForFailure;
        child_handle = actor_factory(child_task_name);
        alive; // Actor is now alive
        while (!stop) {
            receiveTimeout(100.msecs);
        }
    }

    mixin TaskActor; /// Turns the struct into an Actor
}

static assert(isActor!SetUpForDissapointment);

enum supervisor_task_name = "supervisor";
enum child_task_name = "child";

@safe @Scenario("Supervisor with failing child",
        [])
class SupervisorWithFailingChild {
    ActorHandle!SetUpForDissapointment supervisor_handle;

    @Given("a actor #super")
    Document aActorSuper() {
        auto supervisor_factory = actor!SetUpForDissapointment;
        supervisor_handle = supervisor_factory(supervisor_task_name);

        return result_ok;
    }

    @Given("a actor #child")
    Document aActorChild() {
        return result_ok;
    }

    @When("the actor #super start it should start the #child.")
    Document startTheChild() @trusted {
        check(isRunning(supervisor_task_name), "Supervisor is not running");
        supervisor_handle.isChildRunning(child_task_name);
        check(concurrency.receiveOnly!bool, "child has started");
        return result_ok;
    }

    @When("the #child has started then the #child should fail with an exception")
    Document withAnException() {
        alias DissapointmentFactory = ActorFactory!SetUpForFailure;
        auto child_handler = DissapointmentFactory.handler(child_task_name);
        check(child_handler !is child_handler.init, "The child handler failed to initialise");

        child_handler.exceptionalMethod(42);

        return result_ok;
    }

    @Then("the #super actor should catch the #child which failed")
    Document childWhichFailed() @trusted {
        concurrency.receiveTimeout(
                1.seconds,
                (immutable(Exception) e) { writefln("%s", e); });
        return result_ok;
    }

    @Then("the #super actor should restart the child")
    Document restartTheChild() @trusted {
        supervisor_handle.isChildRunning(
                child_task_name);
        check(concurrency.receiveOnly!bool, "child is running again");
        return result_ok;
    }

    @Then("the #super should stop")
    Document superShouldStop() {
        supervisor_handle.stop;
        check(!isRunning(supervisor_task_name), "Supervisor is still running");
        return result_ok;
    }
}
