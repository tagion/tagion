module tagion.testbench.services.actor_supervisor;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;
import tagion.actor.actor;
import std.concurrency;
import tagion.basic.tagionexceptions : TagionException, TaskFailure;
import core.time;
import std.format : format;
import std.exception : assumeWontThrow;

import std.meta;
import std.stdio;

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

class Recoverable : TagionException {
    this(immutable(char)[] msg, string file = __FILE__, size_t line = __LINE__) pure {
        super(msg, file, line);
    }
}

class Fatal : TagionException {
    this(immutable(char)[] msg, string file = __FILE__, size_t line = __LINE__) pure {
        super(msg, file, line);
    }
}

/// Child Actor
struct SetUpForFailure {
static:
    void exceptional1(Msg!"recoverable") {
        writeln("oh nose");
        throw new Exception("I am fail");
    }

    void exceptional2(Msg!"fatal") {
        writeln("oh noes");
        throw new Exception("I am big fail");
    }

    mixin Actor!(&exceptional1, &exceptional2); /// Turns the struct into an Actor
}

alias ChildHandle = ActorHandle!SetUpForFailure;

// How big is the oof.
enum Oof {
    big, // so big the actor should restart
    small, // small enought the actor can keep running
}

enum supervisor_task_name = "supervisor";
enum child_task_name = "child";

/// Supervisor Actor
struct SetUpForDisappointment {
static:
    SetUpForFailure child;
    ChildHandle childHandle;

    void starting() {
        childHandle = spawnActor!SetUpForFailure(child_task_name);
        childrenState[childHandle.tid] = Ctrl.STARTING;

        while (!(childrenState.all(Ctrl.ALIVE))) {
            CtrlMsg msg = receiveOnlyTimeout!CtrlMsg;
            childrenState[msg.tid] = msg.ctrl;
        }
    }

    // Override the default fail handler
    auto fail = (TaskFailure tf) {
        writeln("Received the taskfailure from overrid taskfail");
        try {
            throw tf.throwable;
        }
        catch (Fatal e) {
            writeln("This is fatal");
        }
        catch (Recoverable e) {
            writeln("This is Recoverable");
        }
        catch (MessageMismatch e) {
            writeln("The actor does not handle this type of message");
        }
        catch (Throwable) {
            if (ownerTid !is Tid.init) {
                assumeWontThrow(ownerTid.prioritySend(tf));
            }
        }
    };

    mixin Actor!(); /// Turns the struct into an Actor
}

alias SupervisorHandle = ActorHandle!SetUpForDisappointment;

@safe @Scenario("Supervisor with failing child",
        [])
class SupervisorWithFailingChild {
    SupervisorHandle supervisorHandle;
    ChildHandle childHandle;

    @Given("a actor #super")
    Document aActorSuper() @trusted {
        supervisorHandle = spawnActor!SetUpForDisappointment(supervisor_task_name);
        Ctrl ctrl = receiveOnlyTimeout!CtrlMsg.ctrl;
        check(ctrl is Ctrl.STARTING, "Supervisor is not starting");

        return result_ok;
    }

    @When("the #super and the #child has started")
    Document hasStarted() @trusted {
        auto ctrl = receiveOnlyTimeout!CtrlMsg.ctrl;
        check(ctrl is Ctrl.ALIVE, "Supervisor is not running");

        childHandle = actorHandle!SetUpForFailure(child_task_name);
        check(childHandle.tid !is Tid.init, "Child is not running");

        return result_ok;
    }

    @Then("the #super should send a message to the #child which results in a fail")
    Document aFail() @trusted {
        childHandle.send(Msg!"fatal"());
        return result_ok;
    }

    @Then("the #super actor should catch the #child which failed")
    Document whichFailed() @trusted {
        Tid childTid = locate(child_task_name);
        bool received = receiveTimeout(
                1.seconds,
                (TaskFailure tf) { writefln("Task failed succesfully with: %s", tf.throwable.msg); },
                (Variant val) { check(0, format("Unexpected value: %s", val)); }
        );
        check(received, "Timed out before receiving taskfailure");
        check(childTid !is Tid.init, "Child is not running anymore");
        return result_ok;
    }

    @Then("the #super actor should stop #child and restart it")
    Document restartIt() {
        return Document();
    }

    @Then("the #super should send a message to the #child which results in a different fail")
    Document differentFail() @trusted {
        childHandle.send(Msg!"recoverable"());
        return result_ok;
    }

    @Then("the #super actor should let the #child keep running")
    Document keepRunning() @trusted {
        bool received = receiveTimeout(
                1.seconds,
                (TaskFailure tf) { writefln("Task failed succesfully with: %s", tf.throwable.msg); },
                (Variant val) { check(0, format("Unexpected value: %s", val)); }
        );
        check(received, "Timed out before receiving taskfailure");

        return result_ok;
    }

    @Then("the #super should stop")
    Document superShouldStop() @trusted {
        supervisorHandle.send(Sig.STOP);
        auto ctrl = receiveOnly!CtrlMsg;
        check(ctrl.ctrl is Ctrl.END, "Supervisor did not stop");

        Tid childTid = locate(child_task_name);
        check(childTid !is Tid.init, "Child is still running");

        return result_ok;
    }

}
