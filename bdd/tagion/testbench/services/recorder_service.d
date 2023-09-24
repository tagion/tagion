module tagion.testbench.services.recorder_service;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;
import tagion.services.recorder;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.actor;
import tagion.services.recorder;
import tagion.utils.pretend_safe_concurrency;

enum feature = Feature(
            "Recorder chain service",
            [
        "This services should store the recorder for each epoch in chain as a file.",
        "This is an extension of the Recorder backup chain."
]);

alias FeatureContext = Tuple!(
        StoreOfTheRecorderChain, "StoreOfTheRecorderChain",
        FeatureGroup*, "result"
);

@safe @Scenario("store of the recorder chain",
        [])
class StoreOfTheRecorderChain {
    immutable(RecorderOptions) recorder_opts;
    SecureNet recorder_net;
    RecorderServiceHandle handle;

    this(immutable(RecorderOptions) recorder_opts) {
        this.recorder_opts = recorder_opts;
        recorder_net = new StdSecureNet();
        recorder_net.generateKeyPair("recordernet very secret");
    }
    

    @Given("a epoch recorder with epoch number has been received")
    Document received() {
        thisActor.task_name = "recorder_supervisor";
        register(thisActor.task_name, thisTid);
        handle = (() @trusted => spawn!RecorderService("RecorderService", recorder_opts, cast(immutable) recorder_net))();
        waitforChildren(Ctrl.ALIVE);
        return result_ok;
    }

    @When("the recorder has been store to a file")
    Document file() {
        return Document();
    }

    @Then("the file should be checked")
    Document checked() {
        handle.send(Sig.STOP);
        waitforChildren(Ctrl.END);
        return result_ok;
    }

}
