module tagion.testbench.services.actor_message;

import tagion.actor.Actor;
import core.time;
import std.stdio;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import concurrency = std.concurrency;

enum feature = Feature(
            "Actor messaging",
            ["This feature should verify the message send between actors"]);

alias FeatureContext = Tuple!(
        MessageBetweenSupervisorAndChild, "MessageBetweenSupervisorAndChild",
        SendMessageBetweenTwoChildren, "SendMessageBetweenTwoChildren",
        FeatureGroup*, "result"
);

enum Gettes {
    Some,
    Arg
}

@safe
struct MyActor {
    import tagion.testbench.actor_tests;


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

    /** 
    * Actor method send a opt to the actor and 
    * sends back an a response to the owner task
    */
    /* @method void get(Gettes opt) { // reciever */
    /*     final switch (opt) { */
    /*     case Gettes.Some: */
    /*         sendOwner(some_name); */
    /*         break; */
    /*     case Gettes.Arg: */
    /*         sendOwner(count); */
    /*         break; */
    /*     } */
    /* } */

    mixin TaskActor; /// Turns the struct into an Actor

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

@safe @Scenario("Message between supervisor and child",
        [])
class MessageBetweenSupervisorAndChild {

    enum supervisor_task_name = "supervisor";
    enum child1_task_name = "child1";
    enum child2_task_name = "child2";
    ActorFactory!MySuperActor supervisor_factory;
    ActorHandle!MySuperActor supervisor_handle;
    alias ChildHandle = ActorHandle!MyActor;

    @safe
    static struct MySuperActor {
        ChildHandle niño_uno_handle;
        ChildHandle niño_dos_handle;

        @task void run() {
            auto my_actor_factory = actor!MyActor;

            niño_uno_handle = my_actor_factory(child1_task_name, 10);
            niño_dos_handle = my_actor_factory(child2_task_name, 65);

            alive;
            while (!stop) {
                receive;
            }
        }

        @method void isChildRunning(string task_name) {
            sendOwner(isRunning(task_name));
        }
        
        @method void sendStatusToChild1(int status) {
            niño_dos_handle.decrease(status);
        }

        /* @method void receiveStatusFromChild1(Get get) { */
        /*     return niño_dos_handle.get(get); */
        /* } */

        mixin TaskActor;
    }
    static assert(isActor!MySuperActor);

    @Given("a supervisor #super and two child actors #child1 and #child2")
    Document actorsChild1AndChild2() {
        supervisor_factory = actor!MySuperActor;

        supervisor_handle = supervisor_factory(supervisor_task_name);
        check(isRunning(supervisor_task_name), "Supervisor is running");

        return result_ok;
    }

    @When("the #super has started the #child1 and #child2")
    Document theChild1AndChild2() @trusted {
        supervisor_handle.isChildRunning(child1_task_name);
        check(concurrency.receiveOnly!bool, "child1 is running");

        supervisor_handle.isChildRunning(child2_task_name);
        check(concurrency.receiveOnly!bool, "child2 is running");
        return result_ok;
    }

    @Then("send a message to #child1")
    Document aMessageToChild1() {
        /* supervisor_handle.sendMessageToChild(supervisor_handle.niñoUno_handle, "Do you like candy?"); */
        supervisor_handle.sendStatusToChild1(1);
        return result_ok;
    }

    @Then("send this message back from #child1 to #super")
    Document fromChild1ToSuper() {
        /* writeln(supervisor_handle.receiveStatusFromChild1(Get.Arg)); */

        return result_ok;
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
        supervisor_handle.stop;
        check(!isRunning(child1_task_name), "child1 is still running");
        check(!isRunning(child2_task_name), "child2 is still running");
        return result_ok;
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
