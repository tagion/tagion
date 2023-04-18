module tagion.testbench.services.actor_supervisor;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;
import tagion.actor.actor;
import std.concurrency;

import std.meta;
import std.stdio;

enum feature = Feature(
            "Actor supervisor test",
            ["This feature should check the supervisor fail and restart"]);

alias FeatureContext = Tuple!(
        SupervisorWithFailingChild, "SupervisorWithFailingChild",
        FeatureGroup*, "result"
);

/// Child Actor
struct SetUpForFailure {
static:
    void exceptional(Msg!"exceptional") {
        throw new Exception("I am fail");
    }

    mixin Actor!(&exceptional); /// Turns the struct into an Actor
}

alias ChildHandle = ActorHandle!SetUpForFailure;

/// Supervisor Actor
struct SetUpForDisapointment {
static:
    SetUpForFailure child;

    alias children = AliasSeq!(child);

    void disapoint(Msg!"issapoint") {
        ChildHandle dissapointee = actorHandle!SetUpForFailure(child_task_name);
        dissapointee.send(Msg!"exceptional"());
    }

    mixin Actor!(&disapoint); /// Turns the struct into an Actor
}

alias SupervisorHandle = ActorHandle!SetUpForDisapointment;

enum supervisor_task_name = "supervisor";
enum child_task_name = "0";

@safe @Scenario("Supervisor with failing child",
        [])
class SupervisorWithFailingChild {
    SupervisorHandle supervisorHandle;
    ChildHandle childHandle;

    @Given("a actor #super")
    Document aActorSuper() @trusted {
        supervisorHandle = spawnActor!SetUpForDisapointment(supervisor_task_name);

        Ctrl ctrl = receiveOnly!CtrlMsg.ctrl;
        check(ctrl is Ctrl.STARTING, "Supervisor is not starting");

        ctrl = receiveOnly!CtrlMsg.ctrl;
        check(ctrl is Ctrl.ALIVE, "Supervisor is not alive");

        return result_ok;
    }

    @Given("a actor #child")
    Document aActorChild() {
        return Document();
    }

    @When("the actor #super start it should start the #child.")
    Document startTheChild() @trusted {
        return Document();
    }

    @When("the #child has started then the #child should fail with an exception")
    Document withAnException() {
        return Document();
    }

    @Then("the #super actor should catch the #child which failed")
    Document childWhichFailed() @trusted {
        return Document();
    }

    @Then("the #super actor should restart the child")
    Document restartTheChild() @trusted {
        return Document();
    }

    @Then("the #super should stop")
    Document superShouldStop() @trusted {
        supervisorHandle.send(Sig.STOP);
        auto ctrl = receiveOnly!CtrlMsg;
        check(ctrl.ctrl is Ctrl.END, "Supervisor did not stop");

        return result_ok;
    }
}
