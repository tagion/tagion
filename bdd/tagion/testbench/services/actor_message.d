module tagion.testbench.services.actor_message;

import tagion.actor.Actor;
import core.time;
import std.stdio;
import std.format : format;

// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import concurrency = std.concurrency;
import core.thread;

enum feature = Feature(
            "Actor messaging",
            ["This feature should verify the message send between actors"]);

alias FeatureContext = Tuple!(
        MessageBetweenSupervisorAndChild, "MessageBetweenSupervisorAndChild",
        SendMessageBetweenTwoChildren, "SendMessageBetweenTwoChildren",
        FeatureGroup*, "result"
);

enum Children {
    child1,
    child2,
}

enum supervisor_task_name = "supervisor";
enum child1_task_name = "child1";
enum child1_init = 10; // meaningless value
enum child2_task_name = "child2";
enum child2_init = 65; // meaningless value
enum sleep_time = 100.msecs;

// Child actors
struct MyActor {
    long count;
    string some_name;
    /**
    Actor method which sets the str
    */
    @method void setName(string str) {
        some_name = str;
        debug writeln("sending back to super visor: ", some_name);
        sendSupervisor(some_name, some_name);
    }

    @method void relay(string str, string task_name) {
        alias ChildFactory = ActorFactory!MyActor;

        // Request the handle for the other child;
        ChildHandle otherChild = ChildFactory.handler(task_name);
        debug writefln("Got child handler:%s, %s", otherChild.tid, otherChild is otherChild.init);

        otherChild.setName(str);
    }

    /// Decrease the count value `by`
    @method void decrease(int by) {
        count -= by;
        sendSupervisor(count);
    }

    /// UDA @task mark that this is the task for the Actor
    @task void runningTask(long label) {
        count = label;
        //...
        alive; // Actor is now alive
        while (!stop) {
            receiveTimeout(100.msecs);
        }
    }

    mixin TaskActor; /// Turns the struct into an Actor
}

static assert(isActor!MyActor);

alias ChildHandle = ActorHandle!MyActor;

static struct MySuperActor {
    @safe

    ChildHandle niño_uno_handle;
    ChildHandle niño_dos_handle;

    @task void run() {
        auto my_actor_factory = actor!MyActor;

        niño_uno_handle = my_actor_factory(child1_task_name, child1_init);
        niño_dos_handle = my_actor_factory(child2_task_name, child2_init);

        alive;
        while (!stop) {
            receive;
        }
    }

    @method void isChildRunning(string task_name) {
        Thread.sleep(sleep_time);
        sendSupervisor(isRunning(task_name));
    }

    @method void echo(string str, string str2) {
        sendSupervisor(str, str2);
    }

    @method void sendStatusToChild(int status, Children child) {
        final switch (child) {
        case Children.child1:
            niño_uno_handle.decrease(status);
            break;
        case Children.child2:
            niño_dos_handle.decrease(status);
            break;
        }

        long echo = concurrency.receiveOnly!long;
        sendSupervisor(echo);
    }

    @method void roundtrip(Children __notUsed) {
        niño_uno_handle.relay("hi mom", child2_task_name);
    }

    mixin TaskActor;
}

static assert(isActor!MySuperActor);

@safe @Scenario("Message between supervisor and child",
        [])
class MessageBetweenSupervisorAndChild {
    ActorFactory!MySuperActor supervisor_factory;
    ActorHandle!MySuperActor supervisor_handle;

    @Given("a supervisor #super and two child actors #child1 and #child2")
    Document actorsChild1AndChild2() {
        supervisor_factory = actor!MySuperActor;

        supervisor_handle = supervisor_factory(supervisor_task_name);
        check(isRunning(supervisor_task_name), "Supervisor is not running");

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
        supervisor_handle.sendStatusToChild(1, Children.child1);
        return result_ok;
    }

    @Then("send this message back from #child1 to #super")
    Document fromChild1ToSuper() @trusted {
        long received = concurrency.receiveOnly!long;
        check(received == child1_init - 1, format("The child did not reflect the message, got %s", received));

        return result_ok;
    }

    @Then("send a message to #child2")
    Document aMessageToChild2() {
        supervisor_handle.sendStatusToChild(1, Children.child2);
        return result_ok;
    }

    @Then("send thus message back from #child2 to #super")
    Document fromChild2ToSuper() @trusted {
        long received = concurrency.receiveOnly!long;
        check(received == child2_init - 1, format("The child did not reflect the message, got %s", received));
        return result_ok;
    }

    @Then("stop the #super")
    Document stopTheSuper() {
        supervisor_handle.stop;
        check(!isRunning(supervisor_task_name), "supervisor is still running");
        return result_ok;
    }

}

@safe @Scenario("send message between two children",
        [])
class SendMessageBetweenTwoChildren {

    ActorFactory!MySuperActor supervisor_factory;
    ActorHandle!MySuperActor supervisor_handle;

    @Given("a supervisor #super and two child actors #child1 and #child2")
    Document actorsChild1AndChild2() {
        supervisor_factory = actor!MySuperActor;

        supervisor_handle = supervisor_factory(supervisor_task_name);
        check(isRunning(supervisor_task_name), "Supervisor is not running");
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

    @When("send a message from #super to #child1 and from #child1 to #child2 and back to the #super")
    Document backToTheSuper() @trusted {
        supervisor_handle.roundtrip(Children.child2);

        auto receive = concurrency.receiveOnly!(Tuple!(string, string));
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
