module tagion.testbench.services.actor_supervisor;

import tagion.testbench.services.actor_util;

// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;
import tagion.actor.actor;
import std.concurrency;
import tagion.basic.tagionexceptions : TagionException;
import tagion.actor.exceptions : TaskFailure;
import core.time;
import std.format : format;
import std.exception : assumeWontThrow;

import std.meta;
import std.stdio;

enum feature = Feature(
            "Actor supervisor test",
            [
            "This feature should check that when a child catches an exception is sends it up as a failure.",
            "The supervisour has the abillity to decide whether or not to restart i depending on the exception."
            ]);

alias FeatureContext = Tuple!(
        SupervisorWithFailingChild, "SupervisorWithFailingChild",
        FeatureGroup*, "result"
);

class Recoverable : TagionException {
    this(immutable(char)[] msg, string file = __FILE__, size_t line = __LINE__) pure {
        super(msg, file, line);
    }
}

class Fatal : TagionException {
    this(immutable(char)[] msg, string file = __FILE__, size_t line = __LINE__) pure {
        super(msg, file, line);
    }
}

/// Child Actor
struct SetUpForFailure {
static:
    void recoverable(Msg!"recoverable") {
        writeln("oh nose");
        throw new Recoverable("I am fail");
    }

    void fatal(Msg!"fatal") {
        writeln("oh noes");
        throw new Fatal("I am big fail");
    }

    mixin Actor!(&recoverable, &fatal); /// Turns the struct into an Actor
}

alias ChildHandle = ActorHandle!SetUpForFailure;

enum supervisor_task_name = "supervisor";
enum child_task_name = "childUno";

alias reRecoverable = Msg!"reRecoverable";
alias reFatal = Msg!"reFatal";

/// Supervisor Actor
struct SetUpForDisappointment {
static:
    //SetUpForFailure child;
    ChildHandle childHandle;

    void starting() {
        childHandle = spawn!SetUpForFailure(child_task_name);
        childrenState[childHandle.task_name] = Ctrl.STARTING;

        while (!(childrenState.all(Ctrl.ALIVE))) {
            CtrlMsg msg = receiveOnlyTimeout!CtrlMsg;
            childrenState[msg.task_name] = msg.ctrl;
        }
    }

    // Override the default fail handler
    auto failHandler = (TaskFailure tf) {
        try {
            writefln("Received the taskfailure from overrid taskfail type: %s", typeid(tf.throwable));
            throw tf.throwable;
        }
        catch (Recoverable e) {
            writeln(typeof(e).stringof);
            writeln("This is Recoverable, just let it run");
            sendOwner(reRecoverable());
        }
        catch (Fatal e) {
            writeln(typeof(e).stringof, tf.task_name, locate(tf.task_name));
            childHandle = respawn(childHandle);
            writefln("This is fatal, we need to restart %s", tf.task_name);
            sendOwner(reFatal());
        }
        catch (MessageMismatch e) {
            writeln("The actor does not handle this type of message");
        }
        catch (Throwable) {
            if (ownerTid !is Tid.init) {
                assumeWontThrow(ownerTid.prioritySend(tf));
            }
        }
    };

    mixin Actor!(); /// Turns the struct into an Actor
}

alias SupervisorHandle = ActorHandle!SetUpForDisappointment;

@safe @Scenario("Supervisor with failing child",
        [])
class SupervisorWithFailingChild {
    SupervisorHandle supervisorHandle;
    ChildHandle childHandle;

    @Given("a actor #super")
    Document aActorSuper() @trusted {
        supervisorHandle = spawn!SetUpForDisappointment(supervisor_task_name);
        Ctrl ctrl = receiveOnlyTimeout!CtrlMsg.ctrl;
        check(ctrl is Ctrl.STARTING, "Supervisor is not starting");

        return result_ok;
    }

    @When("the #super and the #child has started")
    Document hasStarted() @trusted {
        auto ctrl = receiveOnlyTimeout!CtrlMsg.ctrl;
        check(ctrl is Ctrl.ALIVE, "Supervisor is not running");

        childHandle = handle!SetUpForFailure(child_task_name);
        check(childHandle.tid !is Tid.init, "Child is not running");

        return result_ok;
    }

    @Then("the #super should send a message to the #child which results in a fail")
    Document aFail() @trusted {
        childHandle.send(Msg!"fatal"());
        return result_ok;
    }

    @Then("the #super actor should catch the #child which failed")
    Document whichFailed() @trusted {
        writeln("Returned ", receiveOnly!reFatal);
        return result_ok;
    }

    @Then("the #super actor should stop #child and restart it")
    Document restartIt() @trusted {
        childHandle = handle!SetUpForFailure(child_task_name); // FIX: actor handle should be transparent
        check(locate(child_task_name) !is Tid.init, "Child thread is not running");
        return result_ok;
    }

    @Then("the #super should send a message to the #child which results in a different fail")
    Document differentFail() @trusted {
        childHandle.send(Msg!"recoverable"());
        check(childHandle.tid !is Tid.init, "Child thread is not running");
        return result_ok;
    }

    @Then("the #super actor should let the #child keep running")
    Document keepRunning() @trusted {
        writeln("Returned ", receiveOnly!reRecoverable);
        check(childHandle.tid !is Tid.init, "Child thread is not running");

        return result_ok;
    }

    @Then("the #super should stop")
    Document superShouldStop() @trusted {
        supervisorHandle.send(Sig.STOP);
        auto ctrl = receiveOnly!CtrlMsg;
        check(ctrl.ctrl is Ctrl.END, "Supervisor did not stop");

        //Tid childTid = locate(child_task_name);
        //check(childTid !is Tid.init, "Child is still running");

        return result_ok;
    }

}
