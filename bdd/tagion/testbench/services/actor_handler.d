module tagion.testbench.services.actor_handler;

import tagion.testbench.services.actor_util;

// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import tagion.utils.pretend_safe_concurrency;
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

enum child_task_name = "handle_child_task";
enum super_task_name = "handle_super_task";

struct MyActor {
    int status = 0;

    void setstatus(Msg!"setstatus", int i, Tid returnTid) {
        status = i;
        send(returnTid, "hey we received that number");
    }

    void task() nothrow {
        run(&setstatus);
    }
}

alias MyActorHandle = ActorHandle!MyActor;

struct MySuperActor {
    MyActorHandle childHandle;

    void task() {
        childHandle = spawn!MyActor(child_task_name);
        waitforChildren(Ctrl.ALIVE);
        run();
    }
}

alias MySuperHandle = ActorHandle!MySuperActor;

@safe @Scenario("send a message to an actor you don't own",
        [])
class SendAMessageToAnActorYouDontOwn {
    MySuperHandle super_actor_handler;
    MyActorHandle child_handler;

    @Given("a supervisor #super and one child actor #child")
    Document actorChild() {
        super_actor_handler = spawn!MySuperActor(super_task_name);

        check(waitforChildren(Ctrl.ALIVE), "Supervisor did not alive");
        return result_ok;
    }

    @When("#we request the handler for #child")
    Document forChild() {
        child_handler = handle!MyActor(child_task_name);
        check(child_handler.tid !is Tid.init, "Child task was not running");
        return result_ok;
    }

    @When("#we send a message to #child")
    Document toChild() {
        child_handler.send(Msg!"setstatus"(), 42, thisTid);
        return result_ok;
    }

    @When("#we receive confirmation that shild has received the message.")
    Document theMessage() {
        string message = receiveOnlyTimeout!string;

        check(message !is string.init, "Never got the confirmation from the child");
        writeln(message);
        return result_ok;
    }

    @Then("stop the #super")
    Document theSuper() {
        super_actor_handler.send(Sig.STOP);
        check(waitforChildren(Ctrl.END), "Child did not end");
        return result_ok;
    }

}
