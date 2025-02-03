module tagion.testbench.actor.supervisor;

import tagion.testbench.actor.util;

// This test is disabled because the restart() functionality of the supervisor
// Was never used and removed, however other parts of the tests are still relevant like the taskfailure handling.
// So it needs to be updated
version (none)  :  // Default import list for bdd
import core.time;
import std.exception : assumeWontThrow;
import std.format : format;
import std.meta;
import std.stdio;
import std.typecons : Tuple;
import tagion.actor.actor;
import tagion.actor.exceptions : TaskFailure;
import tagion.errors.tagionexceptions : TagionException;
import tagion.behaviour;
import tagion.hibon.Document;
import tagion.testbench.tools.Environment;
import tagion.utils.pretend_safe_concurrency;

enum feature = Feature(
            "Actor supervisor test",
            [
        "This feature should check that when a child catches an exception is sends it up as a failure.",
        "The supervisour has the abillity to decide whether or not to restart i depending on the exception."
]);

alias FeatureContext = Tuple!(
        SupervisorWithFailingChild, "SupervisorWithFailingChild",
        FeatureGroup*, "result"
);

@safe
class Recoverable : TagionException {
    this(immutable(char)[] msg, string file = __FILE__, size_t line = __LINE__) pure {
        super(msg, file, line);
    }
}

@safe
class Fatal : TagionException {
    this(immutable(char)[] msg, string file = __FILE__, size_t line = __LINE__) pure {
        super(msg, file, line);
    }
}

/// Child Actor
@safe
struct SetUpForFailure {
    void recoverable(Msg!"recoverable") {
        writeln("oh nose");
        throw new Recoverable("I am fail");
    }

    void fatal(Msg!"fatal") {
        writeln("oh noes");
        throw new Fatal("I am big fail");
    }

    void task() nothrow {
        run(&recoverable, &fatal);
    }
}

alias ChildHandle = ActorHandle!SetUpForFailure;

enum supervisor_task_name = "supervisor";
enum child_task_name = "childUno";

alias reRecoverable = Msg!"reRecoverable";
alias reFatal = Msg!"reFatal";

/// Supervisor Actor
@safe
struct SetUpForDisappointment {
    //SetUpForFailure child;
    static ChildHandle childHandle;

    void task() @safe nothrow {
        childHandle = spawn!SetUpForFailure(child_task_name);
        waitforChildren(Ctrl.ALIVE);
        run(failHandler);
    }

    // Override the default fail handler
    auto failHandler = (TaskFailure tf) @trusted {
        writefln("Received the taskfailure from overrid taskfail type: %s", typeid(tf.throwable));

        if (cast(Recoverable) tf.throwable !is null) {
            writeln(typeof(tf.throwable).stringof);
            writeln("This is Recoverable, just let it run");
            sendOwner(reRecoverable());
        }
        else if (cast(Fatal) tf.throwable !is null) {
            writeln(typeof(tf.throwable).stringof, tf.task_name, locate(tf.task_name));
            childHandle = respawn(childHandle);
            waitforChildren(Ctrl.ALIVE);
            writefln("This is fatal, we need to restart %s", tf.task_name);
            sendOwner(reFatal());
        }
        else if (cast(MessageMismatch) tf.throwable !is null) {
            writeln("The actor does not handle this type of message");
        }
        else {
            if (ownerTid !is Tid.init) {
                assumeWontThrow(ownerTid.prioritySend(tf));
            }
        }
    };
}

alias SupervisorHandle = ActorHandle!SetUpForDisappointment;

@safe @Scenario("Supervisor with failing child",
        [])
class SupervisorWithFailingChild {
    SupervisorHandle supervisorHandle;
    ChildHandle childHandle;

    @Given("a actor #super")
    Document aActorSuper() {
        supervisorHandle = spawn!SetUpForDisappointment(supervisor_task_name);
        check(waitforChildren(Ctrl.ALIVE), "Supervisor is not alive");

        return result_ok;
    }

    @When("the #super and the #child has started")
    Document hasStarted() {
        childHandle = handle!SetUpForFailure(child_task_name);
        check(childHandle.tid !is Tid.init, "Child is not running");

        return result_ok;
    }

    @Then("the #super should send a message to the #child which results in a fail")
    Document aFail() {
        childHandle.send(Msg!"fatal"());
        return result_ok;
    }

    @Then("the #super actor should catch the #child which failed")
    Document whichFailed() {
        writeln("Returned ", receiveOnly!reFatal);
        return result_ok;
    }

    @Then("the #super actor should stop #child and restart it")
    Document restartIt() @trusted {
        childHandle = handle!SetUpForFailure(child_task_name); // FIX: actor handle should be transparent
        import core.thread, core.time;

        Thread.sleep(100.msecs);
        check(childHandle.tid !is Tid.init, "Child thread is not running");
        return result_ok;
    }

    @Then("the #super should send a message to the #child which results in a different fail")
    Document differentFail() {
        childHandle.send(Msg!"recoverable"());
        check(childHandle.tid !is Tid.init, "Child thread is not running");
        return result_ok;
    }

    @Then("the #super actor should let the #child keep running")
    Document keepRunning() {
        writeln("Returned ", receiveOnly!reRecoverable);
        check(childHandle.tid !is Tid.init, "Child thread is not running");

        return result_ok;
    }

    @Then("the #super should stop")
    Document superShouldStop() {
        supervisorHandle.send(Sig.STOP);
        check(waitforChildren(Ctrl.END), "Supervisor did not end");
        return result_ok;
    }

}
