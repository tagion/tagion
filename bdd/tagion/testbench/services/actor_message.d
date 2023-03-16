module tagion.testbench.services.actor_message;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;
import tagion.actor.Actor;

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

    static struct SuperActor {
        @task void run() {
            alias MyActorFactory = ActorHandle!(MyActor);
            alive;
            while (!stop) {
                receive;
            }
        }
        mixin TaskActor;
    }
    
    static struct ChildActor {
        string mood = "none";
        @method void setMood(string str) {
            mood = str;
        }
    }

    @Given("a supervisor #super and two child actors #child1 and #child2")
    Document actorsChild1AndChild2() {
        auto supervisor_factory = actor!SuperActor;
        auto child_factory = actor!ChildActor;

        auto supervisor = supervisor_factory("super");
        auto niñoUno = child_factory("child1");
        auto niñoDos = child_factory("child2");
        
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
