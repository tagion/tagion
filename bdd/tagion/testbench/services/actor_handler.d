module tagion.testbench.services.actor_handler;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import concurrency = std.concurrency;
import tagion.actor.Actor;
import std.stdio;
import core.time;

enum feature = Feature(
            "Actor handler request",
            ["This feature should verify that you can request a handler for an actor that you don\\'t own"]);

alias FeatureContext = Tuple!(
        SendAMessageToAnActorYouDontOwn, "SendAMessageToAnActorYouDontOwn",
        FeatureGroup*, "result"
);


struct MyActor {
    int status = 0;

    @method void setstatus(int i, Tid returnTid) {
        status = i;
        concurrency.send(returnTid, "hey we received that number");
    }

    @task void run() {
        alive; // Actor is now alive
        while (!stop) {
            receiveTimeout(100.msecs);
        }
    }
    mixin TaskActor; /// Turns the struct into an Actor
}
static assert(isActor!MyActor);

enum child_task_name = "child_task";
enum super_task_name = "super_task";

struct MySuperActor {
    ActorHandle!MyActor child_handle;

    @task void run() {
        auto actor_factory = actor!MyActor;

        child_handle = actor_factory(child_task_name);
        check(isRunning(child_task_name), "Child did not start");

        alive; // Actor is now alive
        while (!stop) {
            receiveTimeout(100.msecs);
        }
    }
    mixin TaskActor; /// Turns the struct into an Actor
}
static assert(isActor!MySuperActor);


@safe @Scenario("send a message to an actor you don't own",
        [])
class SendAMessageToAnActorYouDontOwn {
    ActorHandle!MySuperActor super_actor_handler;
    ActorHandle!MyActor child_handler;

    @Given("a supervisor #super and one child actor #child")
    Document actorChild() {
        auto super_factory = actor!MySuperActor;
        super_actor_handler = super_factory(super_task_name);
        check(isRunning(super_task_name), "Supervisour did not start");

        return result_ok;
    }

    @When("#we request the handler for #child")
    Document forChild() {
        alias ChildFactory = ActorFactory!MyActor;
        child_handler = ChildFactory.handler(child_task_name);
        check(child_handler !is child_handler.init, "The child handler failed to initialise");

        return result_ok;
    }

    @When("#we send a message to #child")
    Document toChild() {
        child_handler.setstatus(42, concurrency.thisTid);
        return result_ok;
    }

    @When("#we receive confirmation that shild has received the message.")
    Document theMessage() @trusted {
        string message;
        concurrency.receiveTimeout(1.seconds,
            (string str) {
                message = str;
        });

        check(message !is string.init, "Never got the confirmation from the child");
        writeln(message);
        return result_ok;
    }

    @Then("stop the #super")
    Document theSuper() {
        super_actor_handler.stop;
        check(!isRunning(super_task_name), "#super is stil running");
        return result_ok;
    }

}
