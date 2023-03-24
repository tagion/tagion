module tagion.testbench.services.actor_supervisor;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import core.time;
import tagion.actor.Actor;

enum feature = Feature(
            "Actor supervisor test",
            ["This feature should check the supervisor fail and restart"]);

alias FeatureContext = Tuple!(
        SupervisorWithFailingChild, "SupervisorWithFailingChild",
        FeatureGroup*, "result"
);

/// Child Actor
struct SetUpForFailure {
    @task void run() {
        alive; // Actor is now alive
        while (!stop) {
            receiveTimeout(100.msecs);
        }
    }
    mixin TaskActor; /// Turns the struct into an Actor
}
static assert(isActor!SetUpForFailure);

/// Supervisor Actor
struct SetUpForDissapointment {
    @task void run() {
        alive; // Actor is now alive
        while (!stop) {
            receiveTimeout(100.msecs);
        }
    }
    mixin TaskActor; /// Turns the struct into an Actor
}
static assert(isActor!SetUpForDissapointment);

@safe @Scenario("Supervisor with failing child",
        [])
class SupervisorWithFailingChild {

    @Given("a actor #super")
    Document aActorSuper() {
        return Document();
    }

    @Given("a actor #child")
    Document aActorChild() {
        return Document();
    }

    @When("the actor #super start it should start the #child.")
    Document startTheChild() {
        return Document();
    }

    @When("the #child has started then the #child should fail with an exception")
    Document withAnException() {
        return Document();
    }

    @Then("the #super actor should catch the #child which failed")
    Document childWhichFailed() {
        return Document();
    }

    @Then("the #super actor should restart the child")
    Document restartTheChild() {
        return Document();
    }

    @Then("the #super should stop")
    Document superShouldStop() {
        return Document();
    }
}
