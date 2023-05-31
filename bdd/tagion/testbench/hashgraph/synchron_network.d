module tagion.testbench.hashgraph.synchron_network;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

enum feature = Feature(
            "Bootstrap of hashgraph",
            []);

alias FeatureContext = Tuple!(
        StartNetworkWithNAmountOfNodes, "StartNetworkWithNAmountOfNodes",
        FeatureGroup*, "result"
);

@safe @Scenario("Start network with n amount of nodes",
        [])
class StartNetworkWithNAmountOfNodes {

    @Given("i have a HashGraph TestNetwork with n number of nodes")
    Document nodes() {
        return Document();
    }

    @When("the network has started")
    Document started() {
        return Document();
    }

    @When("all nodes are sending ripples")
    Document ripples() {
        return Document();
    }

    @When("all nodes are coherent")
    Document coherent() {
        return Document();
    }

    @Then("wait until the first epoch")
    Document epoch() {
        return Document();
    }

    @Then("stop the network")
    Document network() {
        return Document();
    }

}
