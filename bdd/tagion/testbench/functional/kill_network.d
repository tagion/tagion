module tagion.testbench.functional.kill_network;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import std.file;

import tagion.testbench.functional.create_network_in_mode_one;
import tagion.testbench.tools.network;
import std.process;
import std.stdio;
import std.regex;
import std.conv;
import core.thread;

import core.sys.posix.signal;

enum feature = Feature("Kill the network.", []);

alias FeatureContext = Tuple!(KillTheNetworkWithPIDS, "KillTheNetworkWithPIDS", FeatureGroup*, "result");

@safe @Scenario("Kill the network with PIDS.", [])
class KillTheNetworkWithPIDS {
    Node[] network;

    this(CreateNetworkWithNAmountOfNodesInModeone network) {
        this.network = network.nodes;
    }

    @Given("i have a network with pids of the processes.")
    Document processes() {
        return result_ok;
    }

    @When("i send two kill commands.")
    Document commands() @trusted {
        foreach(node; network) {
            writefln("%s", node.pid.processID);
            kill(node.pid, SIGKILL);
            Thread.sleep(100.msecs);
            kill(node.pid, SIGKILL);
            wait(node.pid);
        }  
        return result_ok;
    }

    @Then("check if the network has been stopped.")
    Document stopped() {
        return result_ok;
    }

}
