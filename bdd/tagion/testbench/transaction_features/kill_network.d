module tagion.testbench.transaction_features.kill_network;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import std.file;

import tagion.testbench.transaction_features.create_network;
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
    CreateNetworkWithNAmountOfNodesInModeone network;
    this(CreateNetworkWithNAmountOfNodesInModeone network) {
        this.network = network;
    }

    @Given("a network with pid_files of the processes.")
    Document processes() {
        check(network.pids.length == network.number_of_nodes, "PIDs missing");
        return result_ok;
    }

    @When("i send two kill commands.")
    Document commands() @trusted {
        foreach(pid; network.pids) {
            writefln("%s", pid.processID);
            kill(pid, SIGKILL);
            Thread.sleep(100.msecs);
            kill(pid, SIGKILL);
            wait(pid);
        }  
        return result_ok;
    }

    @Then("check if the network has been stopped.")
    Document stopped() {
        return result_ok;
    }

}
