
module tagion.testbench.hashgraph.round_fingerprint;

// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import std.stdio;


enum feature = Feature(
    "Deterministic round fingerprint", []);

alias FeatureContext = Tuple!(
    SameRoundFingerprintAcrossDifferentNodes, "SameRoundFingerprintAcrossDifferentNodes",
FeatureGroup*, "result"
);


@safe @Scenario("Same round fingerprint across different nodes",
[])
    class SameRoundFingerprintAcrossDifferentNodes {
            
@Given("I have a HashGraph TestNetwork with n number of nodes")
Document nodes() {
        writefln("THIS IS A WOWO TEST");
        return Document();
    }

@When("the network has started")
Document started() {
        return Document();
    }

@Then("wait until the first epoch")
Document epoch() {
        return Document();
    }

@Then("check that the nodes have the same round fingerprint")
Document fingerprint() {
        return Document();
    }
    
}
