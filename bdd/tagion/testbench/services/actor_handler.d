module tagion.testbench.services.actor_handler;

import tagion.testbench.services.actor_util;

// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import std.concurrency;
import tagion.actor.actor;
import std.stdio;
import core.time;

enum feature = Feature(
            "Actor handler request",
            ["This feature should verify that you can request a handler for an actor that you don\\'t own"]);

alias FeatureContext = Tuple!(
        SendAMessageToAnActorYouDontOwn, "SendAMessageToAnActorYouDontOwn",
        FeatureGroup*, "result"
);

enum child_task_name = "child_task";
enum super_task_name = "super_task";

struct MyActor {
    int status = 0;

    void setstatus(Msg!"setstatus", int i, Tid returnTid) {
        status = i;
        send(returnTid, "hey we received that number");
    }

    mixin Actor!(&setstatus); /// Turns the struct into an Actor
}

alias MyActorHandle = ActorHandle!MyActor;

struct MySuperActor {
static:
    MyActorHandle childHandle;

    void starting() {
        childHandle = spawn!MyActor(child_task_name);

        childrenState[childHandle.task_name] = Ctrl.STARTING;

        while (!(childrenState.all(Ctrl.ALIVE))) {
            CtrlMsg msg = receiveOnlyTimeout!CtrlMsg;
            childrenState[msg.task_name] = msg.ctrl;
        }
    }

    mixin Actor!(); /// Turns the struct into an Actor
}

alias MySuperHandle = ActorHandle!MySuperActor;

@safe @Scenario("send a message to an actor you don't own",
        [])
class SendAMessageToAnActorYouDontOwn {
    MySuperHandle super_actor_handler;
    MyActorHandle child_handler;

    @Given("a supervisor #super and one child actor #child")
    Document actorChild() @trusted {
        super_actor_handler = spawn!MySuperActor(super_task_name);

        Ctrl ctrl = receiveOnlyTimeout!CtrlMsg.ctrl;
        check(ctrl is Ctrl.STARTING, "Supervisor is not starting");

        ctrl = receiveOnlyTimeout!CtrlMsg.ctrl;
        check(ctrl is Ctrl.ALIVE, "Supervisor is not running");

        return result_ok;
    }

    @When("#we request the handler for #child")
    Document forChild() @trusted {
        child_handler = handle!MyActor(child_task_name);
        check(child_handler.tid !is Tid.init, "Child task was not running");
        return result_ok;
    }

    @When("#we send a message to #child")
    Document toChild() @trusted {
        child_handler.send(Msg!"setstatus"(), 42, thisTid);
        return result_ok;
    }

    @When("#we receive confirmation that shild has received the message.")
    Document theMessage() @trusted {
        string message = receiveOnlyTimeout!string;

        check(message !is string.init, "Never got the confirmation from the child");
        writeln(message);
        return result_ok;
    }

    @Then("stop the #super")
    Document theSuper() @trusted {
        super_actor_handler.send(Sig.STOP);
        return result_ok;
    }

}
