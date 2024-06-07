module tagion.testbench.actor.taskfailure;

import tagion.testbench.actor.util;

// Default import list for bdd
import core.time;
import std.format : format;
import std.stdio;
import std.typecons : Tuple;
import tagion.actor.actor;
import tagion.actor.exceptions;
import tagion.basic.tagionexceptions;
import tagion.behaviour;
import tagion.hibon.Document;
import tagion.testbench.tools.Environment;
import tagion.utils.pretend_safe_concurrency;

enum feature = Feature(
            "Actor TaskFailure",
            ["While there is no handling of that type of taskfailure resend it up to the owner."]);

alias FeatureContext = Tuple!(
        SendATaskFailureToAnActor, "SendATaskFailureToAnActor",
        FeatureGroup*, "result"
);

enum actor_task = "actor_task";

@safe
struct MyActor {
    void task() nothrow {
        run();
    }
}

@safe @Scenario("Send a TaskFailure to an actor",
        [])
class SendATaskFailureToAnActor {
    ActorHandle myActor;

    @Given("an #actor")
    Document anActor() {
        myActor = spawn!MyActor(actor_task);

        return result_ok;
    }

    @When("the #actor has started")
    Document actorHasStarted() {
        check(waitforChildren(Ctrl.ALIVE), "Actor never alived");
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
                (TaskFailure tf) @safe {
            writefln("Task failed successfully with: %s, %s", typeid(tf.throwable), tf.throwable.msg);
        },
                (Variant val) @trusted { check(0, format("Unexpected value: %s", val)); }
        );
        check(received, "Timed out before receiving taskfailure");
        return result_ok;
    }

    @Then("stop the #actor")
    Document stopTheActor() {
        myActor.send(Sig.STOP);
        check(waitforChildren(Ctrl.END), "Actor never stopped");
        return result_ok;
    }

}
