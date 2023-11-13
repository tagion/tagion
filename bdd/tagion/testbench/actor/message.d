module tagion.testbench.actor.message;

import core.time;
import std.format : format;
import std.meta;
import std.stdio;
import std.variant : Variant;
import tagion.actor.actor;
import tagion.testbench.actor.util;
import tagion.utils.pretend_safe_concurrency;

// Default import list for bdd
import core.thread;
import std.typecons : Tuple;
import tagion.behaviour;
import tagion.hibon.Document;
import tagion.testbench.tools.Environment;

enum feature = Feature(
            "Actor messaging",
            ["This feature should verify the message send between actors"]);

alias FeatureContext = Tuple!(
        MessageBetweenSupervisorAndChild, "MessageBetweenSupervisorAndChild",
        SendMessageBetweenTwoChildren, "SendMessageBetweenTwoChildren",
        FeatureGroup*, "result"
);

enum supervisor_task_name = "supervisor";
enum child1_task_name = "ch1ld";
enum child2_task_name = "ch2ld";

// Child actor
@safe
struct MyActor {
    int counter = 0;
    void increase(Msg!"increase") {
        counter++;
        sendOwner(Msg!"response"(), counter);
    }

    void decrease(Msg!"decrease") {
        counter--;
        sendOwner(Msg!"response"(), counter);
    }

    void relay(Msg!"relay", string to, string message) {
        locate(to).send(Msg!"relay"(), supervisor_task_name, message);
    }

    void task() nothrow {
        run(&increase, &decrease, &relay);
    }
}

alias ChildHandle = ActorHandle!MyActor;

@safe
struct MySuperActor {
    ChildHandle child1Handle;
    ChildHandle child2Handle;

    void receiveStatus(Msg!"response", int status) {
        sendOwner(status);
    }

    void roundtrip(Msg!"roundtrip", string message) {
        child1Handle.send(Msg!"relay"(), child2_task_name, message);
    }

    void relay(Msg!"relay", string _, string message) {
        sendOwner(message);
    }

    void task() nothrow {
        child1Handle = spawn!MyActor(child1_task_name);
        child2Handle = spawn!MyActor(child2_task_name);

        waitforChildren(Ctrl.ALIVE);
        run(&receiveStatus, &roundtrip, &relay);
    }

}

alias SupervisorHandle = ActorHandle!MySuperActor;

@safe @Scenario("Message between supervisor and child",
        [])
class MessageBetweenSupervisorAndChild {
    SupervisorHandle supervisorHandle;
    ChildHandle childHandleUno;
    ChildHandle childHandleDos;

    @Given("a supervisor #super and two child actors #child1 and #child2")
    Document actorsChild1AndChild2() {
        supervisorHandle = spawn!MySuperActor(supervisor_task_name);

        check(waitforChildren(Ctrl.ALIVE), "Supervisor did not alive");
        check(supervisorHandle.tid !is Tid.init, "Supervisor thread is not running");

        return result_ok;
    }

    @When("the #super has started the #child1 and #child2")
    Document theChild1AndChild2() {
        // The supervisor should only send alive when it has receive alive from the children.
        // we assign the child handles
        childHandleUno = handle!MyActor(child1_task_name);
        childHandleDos = handle!MyActor(child2_task_name);

        return result_ok;
    }

    @Then("send a message to #child1")
    Document aMessageToChild1() {
        check(locate(child1_task_name) !is Tid.init, "Child 1 thread is not running");
        childHandleUno.send(Msg!"increase"());

        return result_ok;
    }

    @Then("send this message back from #child1 to #super")
    Document fromChild1ToSuper() {
        check(receiveOnlyTimeout!int == 1, "Child 1 did not send back the expected value of 1");

        return result_ok;
    }

    @Then("send a message to #child2")
    Document aMessageToChild2() {
        childHandleDos.send(Msg!"decrease"());
        return result_ok;
    }

    @Then("send thus message back from #child2 to #super")
    Document fromChild2ToSuper() {
        check(receiveOnlyTimeout!int == -1, "Child 2 did not send back the expected value of 1");
        return result_ok;
    }

    @Then("stop the #super")
    Document stopTheSuper() {
        supervisorHandle.send(Sig.STOP);
        check(waitforChildren(Ctrl.END), "Supervisor did not end");

        return result_ok;
    }

}

@safe @Scenario("send message between two children",
        [])
class SendMessageBetweenTwoChildren {
    SupervisorHandle supervisorHandle;
    ChildHandle childHandleUno;
    ChildHandle childHandleDos;

    @Given("a supervisor #super and two child actors #child1 and #child2")
    Document actorsChild1AndChild2() {
        supervisorHandle = spawn!MySuperActor(supervisor_task_name);
        check(waitforChildren(Ctrl.ALIVE), "Supervisor is not alive");
        check(supervisorHandle.tid !is Tid.init, "Supervisor thread is not running");

        return result_ok;
    }

    @When("the #super has started the #child1 and #child2")
    Document theChild1AndChild2() {
        // The supervisor should only send alive when it has receive alive from the children.
        // we assign the child handles
        childHandleUno = handle!MyActor(child1_task_name);
        childHandleDos = handle!MyActor(child2_task_name);

        return result_ok;
    }

    @When("send a message from #super to #child1 and from #child1 to #child2 and back to the #super")
    Document backToTheSuper() {

        enum message = "Hello Tagion";
        supervisorHandle.send(Msg!"roundtrip"(), message);
        check(receiveOnlyTimeout!string == message, "Did not get the same message back");

        return result_ok;
    }

    @Then("stop the #super")
    Document stopTheSuper() {
        supervisorHandle.send(Sig.STOP);
        check(waitforChildren(Ctrl.END), "Supervisor did not end ");
        return result_ok;
    }
}
