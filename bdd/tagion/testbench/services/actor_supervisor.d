module tagion.testbench.services.actor_supervisor;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;
import tagion.actor.actor;
import std.concurrency;
import tagion.basic.tagionexceptions : TagionException;

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
        throw new Recoverable("I am fail");
    }

    void exceptional2(Msg!"fatal") {
        throw new Fatal("I am big fail");
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
            CtrlMsg msg = receiveOnly!CtrlMsg; // HACK: don't use receiveOnly
            childrenState[msg.tid] = msg.ctrl;
        }
    }

    //void failHandler(Exception e) {
    //    writeln("Received Exce: ", e);
    //    immutable exception = cast(immutable) e;
    //    assumeWontThrow(ownerTid.prioritySend(exception));
    //}

    void disappoint(Msg!"disappoint", Oof disappointment) {
        final switch (disappointment) {
        case Oof.big:
            childHandle.send(Msg!"fatal"());
            break;
        case Oof.small:
            childHandle.send(Msg!"recoverable"());
            break;
        }
    }

    mixin Actor!(&disappoint); /// Turns the struct into an Actor
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
        Ctrl ctrl = receiveOnly!CtrlMsg.ctrl;
        check(ctrl is Ctrl.STARTING, "Supervisor is not starting");

        return result_ok;
    }

    @When("the #super and the #child has started")
    Document hasStarted() @trusted {
        auto ctrl = receiveOnly!CtrlMsg.ctrl;
        check(ctrl is Ctrl.ALIVE, "Supervisor is not running");

        return result_ok;
    }

    version (none) @Then("the #super should send a message to the #child which results in a fail")
    Document aFail() @trusted {
        supervisorHandle.send(Msg!"disappoint"(), Oof.big);
        return result_ok;
    }

    version (none) @Then("the #super actor should catch the #child which failed")
    Document whichFailed() {
        return Document();
    }

    version (none) @Then("the #super actor should stop #child and restart it")
    Document restartIt() {
        return Document();
    }

    @Then("the #super should send a message to the #child which results in a different fail")
    Document differentFail() @trusted {
        supervisorHandle.send(Msg!"disappoint"(), Oof.small);
        return result_ok;
    }

    @Then("the #super actor should let the #child keep running")
    Document keepRunning() @trusted {
        //writeln(receiveOnly!CtrlMsg);
        writeln(receiveOnly!Recoverable);
        return result_ok;
    }

    @Then("the #super should stop")
    Document superShouldStop() @trusted {
        supervisorHandle.send(Sig.STOP);
        auto ctrl = receiveOnly!CtrlMsg;
        check(ctrl.ctrl is Ctrl.END, "Supervisor did not stop");

        return result_ok;
    }

}
