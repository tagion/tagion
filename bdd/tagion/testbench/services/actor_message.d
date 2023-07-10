module tagion.testbench.services.actor_message;

import tagion.testbench.services.actor_util;
import tagion.actor.actor;
import core.time;
import std.stdio;
import std.format : format;
import std.meta;
import std.variant : Variant;
import tagion.utils.pretend_safe_concurrency;

// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import core.thread;

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
struct MyActor {
static:
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

    void task(string task_name) nothrow {
        run(task_name, &increase, &decrease, &relay);
        end(task_name);
    }
}

alias ChildHandle = ActorHandle!MyActor;

struct MySuperActor {
static:
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

    void task(string task_name) nothrow {
        child1Handle = spawn!MyActor(child1_task_name);
        child2Handle = spawn!MyActor(child2_task_name);

        waitfor(Ctrl.ALIVE, child1Handle, child2Handle);

        run(task_name, &receiveStatus, &roundtrip, &relay);
        end(task_name);
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

        check(supervisorHandle.tid !is Tid.init, "Supervisor thread is not running");
        Ctrl ctrl = receiveOnlyTimeout!CtrlMsg.ctrl;
        check(ctrl is Ctrl.STARTING, "Supervisor is not starting");

        ctrl = receiveOnlyTimeout!CtrlMsg.ctrl;
        check(ctrl is Ctrl.ALIVE, "Supervisor is not alive");

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
        Ctrl ctrl = receiveOnlyTimeout!CtrlMsg.ctrl;
        check(ctrl is Ctrl.END, "The supervisor did not stop");

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
        check(supervisorHandle.tid !is Tid.init, "Supervisor thread is not running");

        CtrlMsg ctrl = receiveOnlyTimeout!CtrlMsg;
        check(ctrl.ctrl is Ctrl.STARTING, "Supervisor is not starting");

        ctrl = receiveOnlyTimeout!CtrlMsg;
        check(ctrl.ctrl is Ctrl.ALIVE, "Supervisor is not alive");

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
        CtrlMsg ctrl = receiveOnlyTimeout!CtrlMsg;
        check(ctrl.ctrl is Ctrl.END, "The supervisor did not stop");
        while (locate(supervisor_task_name) !is Tid.init) {
        }
        check(locate(supervisor_task_name) is Tid.init, "SuperVisor thread is still running");
        return result_ok;
    }

    @Then("check the #child1 and #child2 threads are stopped")
    Document child2ThreadsAreStopped() {
        while (locate(child1_task_name) !is Tid.init) {
        }
        check(locate(child1_task_name) is Tid.init, "Child 1 thread is still running");
        while (locate(child2_task_name) !is Tid.init) {
        }
        check(locate(child2_task_name) is Tid.init, "Child 2 thread is still running");
        return result_ok;
    }

}
