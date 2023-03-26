module tagion.testbench.services.actor_supervisor;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import core.time;
import std.format: format;
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
    
    @method void fail(int _i) {
        throw new Exception("Child: I am a failure");
    }
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

enum supervisor_task_name = "supervisor";
enum child_task_name = "child";

@safe @Scenario("Supervisor with failing child",
        [])
class SupervisorWithFailingChild {
    ActorHandle!SetUpForDissapointment supervisor_handle;

    @Given("a actor #super")
    Document aActorSuper() {
        auto supervisor_factory = actor!SetUpForDissapointment;
        supervisor_handle = supervisor_factory(supervisor_task_name);

        return result_ok;
    }

    @Given("a actor #child")
    Document aActorChild() {
        return result_ok;
    }

    @When("the actor #super start it should start the #child.")
    Document startTheChild() {
        check(isRunning(supervisor_task_name), "Supervisor is not running");
        check(isRunning(child_task_name), "Child is not running");
        return result_ok;
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
        supervisor_handle.stop;
        check(!isRunning(child_task_name), "Child is still running");
        check(!isRunning(supervisor_task_name), "Supervisor is still running");
        return result_ok;
    }
}
