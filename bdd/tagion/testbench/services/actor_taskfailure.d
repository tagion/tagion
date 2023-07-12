module tagion.testbench.services.actor_taskfailure;

import tagion.testbench.services.actor_util;

// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;
import tagion.utils.pretend_safe_concurrency;
import std.stdio;
import core.time;
import std.format : format;

import tagion.basic.tagionexceptions;
import tagion.actor.actor;
import tagion.actor.exceptions;

enum feature = Feature(
            "Actor TaskFailure",
            ["While there is no handling of that type of taskfailure resend it up to the owner."]);

alias FeatureContext = Tuple!(
        SendATaskFailureToAnActor, "SendATaskFailureToAnActor",
        FeatureGroup*, "result"
);

enum actor_task = "actor_task";

struct MyActor {
static:

    void task(string task_name) nothrow {
        run(task_name);
        end();
    }
}

alias MyActorHandle = ActorHandle!MyActor;

@safe @Scenario("Send a TaskFailure to an actor",
        [])
class SendATaskFailureToAnActor {
    MyActorHandle myActor;

    @Given("an #actor")
    Document anActor() {
        myActor = spawn!MyActor(actor_task);

        return result_ok;
    }

    @When("the #actor has started")
    Document actorHasStarted() {
        check(receiveOnlyTimeout!CtrlMsg.ctrl is Ctrl.STARTING, "Actor is not starting");
        check(receiveOnlyTimeout!CtrlMsg.ctrl is Ctrl.ALIVE, "Actor never alived");
        check(myActor.tid !is Tid.init, "Actor task is not running");

        return result_ok;
    }

    @Then("send a `TaskFailure` to the actor")
    Document toTheActor() {
        myActor.send(TaskFailure("main", new immutable Exception("This big fail")));
        return result_ok;
    }

    @Then("the actor should echo it back to the main thread")
    Document theMainThread() {
        bool received = receiveTimeout(
                1.seconds,
                (TaskFailure tf) {
            writefln("Task failed succesfully with: %s, %s", typeid(tf.throwable), tf.throwable.msg);
        },
                (Variant val) { check(0, format("Unexpected value: %s", val)); }
        );
        check(received, "Timed out before receiving taskfailure");
        return result_ok;
    }

    @Then("stop the #actor")
    Document stopTheActor() {
        myActor.send(Sig.STOP);
        check(receiveOnly!CtrlMsg.ctrl !is Ctrl.ALIVE, "Actor never stopped");
        return result_ok;
    }

}
