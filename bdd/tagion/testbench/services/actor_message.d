module tagion.testbench.services.actor_message;

import tagion.actor.actor;
import core.time;
import std.stdio;
import std.format : format;

// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;
import tagion.basic.basic : TrustedConcurrency;

//import std.variant;

mixin TrustedConcurrency;

import core.thread;

enum feature = Feature(
            "Actor messaging",
            ["This feature should verify the message send between actors"]);

alias FeatureContext = Tuple!(
        MessageBetweenSupervisorAndChild, "MessageBetweenSupervisorAndChild", //SendMessageBetweenTwoChildren, "SendMessageBetweenTwoChildren",
        FeatureGroup*, "result"
);

enum supervisor_task_name = "supervisor";
enum child1_task_name = "child1";
enum child2_task_name = "child2";

// Child actor
struct MyActor {
static:
    int counter = 0;
    void increase(Msg!"increase") {
        counter++;
    }

    mixin Actor!(&increase); /// Turns the struct into an Actor
}

alias ChildHandle = ActorHandle!MyActor;

struct MySuperActor {
static:
    void increase(Msg!"increase") {
    }

    mixin Actor!(&increase); /// Turns the struct into an Actor
}

alias SupervisorHandle = ActorHandle!MySuperActor;

@safe @Scenario("Message between supervisor and child",
        [])
class MessageBetweenSupervisorAndChild {
    SupervisorHandle supervisorHandle;
    ChildHandle childHandleUno;
    ChildHandle childHandleDos;

    @Given("a supervisor #super and two child actors #child1 and #child2")
    Document actorsChild1AndChild2() @trusted {
        supervisorHandle = spawnActor!MySuperActor(supervisor_task_name);

        Ctrl ctrl = receiveOnly!CtrlMsg.ctrl;
        check(ctrl is Ctrl.STARTING, "Supervisor is not starting");

        ctrl = receiveOnly!CtrlMsg.ctrl;
        check(ctrl is Ctrl.ALIVE, "Supervisor is not alive");

        return result_ok;
    }

    @When("the #super has started the #child1 and #child2")
    Document theChild1AndChild2() @trusted {
        // The supervisor should only send alive when it has receive alive from the children.
        // we assign the child handles
        childHandleUno = actorHandle!MyActor(child1_task_name);
        childHandleDos = actorHandle!MyActor(child2_task_name);

        return result_ok;
    }

    @Then("send a message to #child1")
    Document aMessageToChild1() @trusted {
        childHandleUno.send(Msg!"increase"());
        return result_ok;
    }

    @Then("send this message back from #child1 to #super")
    Document fromChild1ToSuper() @trusted {
        return result_ok;
    }

    @Then("send a message to #child2")
    Document aMessageToChild2() {
        return result_ok;
    }

    @Then("send thus message back from #child2 to #super")
    Document fromChild2ToSuper() @trusted {
        return result_ok;
    }

    @Then("stop the #super")
    Document stopTheSuper() @trusted {
        supervisorHandle.send(Sig.STOP);
        Ctrl ctrl = receiveOnly!CtrlMsg.ctrl;
        check(ctrl is Ctrl.END, "The supervisor did not stop");

        return result_ok;
    }

}

version (none) @safe @Scenario("send message between two children",
        [])
class SendMessageBetweenTwoChildren {

    @Given("a supervisor #super and two child actors #child1 and #child2")
    Document actorsChild1AndChild2() {
        supervisor_factory = actor!MySuperActor;

        supervisorHandle = supervisor_factory(supervisor_task_name);
        check(isRunning(supervisor_task_name), "Supervisor is not running");
        return result_ok;
    }

    @When("the #super has started the #child1 and #child2")
    Document theChild1AndChild2() @trusted {
        supervisor_handle.isChildRunning(child1_task_name);
        check(receiveOnly!bool, "child1 is running");
        supervisor_handle.isChildRunning(child2_task_name);
        check(receiveOnly!bool, "child2 is running");
        return result_ok;
    }

    @When("send a message from #super to #child1 and from #child1 to #child2 and back to the #super")
    Document backToTheSuper() @trusted {
        supervisor_handle.roundtrip(Children.child2);

        auto receive = receiveOnly!(Tuple!(string, string));
        check(receive[0] == "hi mom", format("did not receive the right message, got %s", receive));
        return result_ok;
    }

    @Then("stop the #super")
    Document stopTheSuper() {
        supervisor_handle.stop;
        check(!isRunning(supervisor_task_name), "supervisor is still running");
        return result_ok;
    }

}
