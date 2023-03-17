module tagion.testbench.services.actor_message;

import tagion.actor.Actor;
import core.time;
import std.stdio;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;


enum feature = Feature(
            "Actor messaging",
            ["This feature should verify the message send between actors"]);

alias FeatureContext = Tuple!(
        MessageBetweenSupervisorAndChild, "MessageBetweenSupervisorAndChild",
        SendMessageBetweenTwoChildren, "SendMessageBetweenTwoChildren",
        FeatureGroup*, "result"
);

@safe @Scenario("Message between supervisor and child",
        [])
class MessageBetweenSupervisorAndChild {

    /* private enum Get { */
    /*     Some, */
    /*     Arg */
    /* } */

    @safe
    private struct MyActor {
        long count;
        string some_name;
        /**
        Actor method which sets the str
        */
        @method void some(string str) {
            some_name = str;
        }

        /// Decrease the count value `by`
        @method void decrease(int by) {
            count -= by;
        }

        /*/1** */ 
        /** Actor method send a opt to the actor and */ 
        /** sends back an a response to the owner task */
        /**1/ */
        /*@method void get(Get opt) { // reciever */
        /*    final switch (opt) { */
        /*    case Get.Some: */
        /*        sendOwner(some_name); */
        /*        break; */
        /*    case Get.Arg: */
        /*        sendOwner(count); */
        /*        break; */
        /*    } */
        /*} */

        mixin TaskActor; /// Thes the struct into an Actor

        /// UDA @task mark that this is the task for the Actor
        @task void runningTask(long label) {
            count = label;
            //...
            alive; // Actor is now alive
            while (!stop) {
                receiveTimeout(100.msecs);
            }
        }
    }
    static assert(isActor!MyActor);


    enum superviser_task_name = "supervise";
    enum child1_task_name = "child1";
    enum child2_task_name = "child2";
    @safe
    static struct MySuperActor {
        @task void run() {
            auto my_actor_factory = actor!MyActor;
            /* ActorHandle!(MyActor); */
            auto niñoUno = my_actor_factory (child1_task_name, 10);
            auto niñoDos = my_actor_factory (child2_task_name, 10);
            alive;
            while (!stop) {
                receive;
            }
        }

        mixin TaskActor;
    }
    static assert(isActor!MySuperActor);

    @Given("a supervisor #super and two child actors #child1 and #child2")
    Document actorsChild1AndChild2() {
        auto supervisor_factory = actor!MySuperActor;

        supervisor_factory(superviser_task_name);

        return Document();
    }

    @When("the #super has started the #child1 and #child2")
    Document theChild1AndChild2() {
        return Document();
    }

    @Then("send a message to #child1")
    Document aMessageToChild1() {
        return Document();
    }

    @Then("send this message back from #child1 to #super")
    Document fromChild1ToSuper() {
        return Document();
    }

    @Then("send a message to #child2")
    Document aMessageToChild2() {
        return Document();
    }

    @Then("send thus message back from #child2 to #super")
    Document fromChild2ToSuper() {
        return Document();
    }

    @Then("stop the #super")
    Document stopTheSuper() {
        return Document();
    }

}

@safe @Scenario("send message between two children",
        [])
class SendMessageBetweenTwoChildren {

    @Given("a supervisor #super and two child actors #child1 and #child2")
    Document actorsChild1AndChild2() {
        return Document();
    }

    @When("the #super has started the #child1 and #child2")
    Document theChild1AndChild2() {
        return Document();
    }

    @When("send a message from #super to #child1 and from #child1 to #child2 and back to the #super")
    Document backToTheSuper() {
        return Document();
    }

    @Then("stop the #super")
    Document stopTheSuper() {
        return Document();
    }

}
