module tagion.testbench.functional.kill_network;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import std.file;

import tagion.testbench.functional.create_network_in_mode_one;
import tagion.testbench.functional.create_network_in_mode_zero;
import tagion.testbench.tools.network;
import std.process;
import std.stdio;
import std.regex;
import std.conv;
import core.thread;
import tagion.testbench.tools.BDDOptions;


import core.sys.posix.signal;

enum feature = Feature("Kill the network.", []);

alias FeatureContext = Tuple!(KillTheNetworkWithPIDS, "KillTheNetworkWithPIDS", FeatureGroup*, "result");

@safe @Scenario("Kill the network with PIDS.", [])
class KillTheNetworkWithPIDS {
    Node[] network;
    BDDOptions bdd_options;

    this(CreateNetworkWithNAmountOfNodesInModeone network, BDDOptions bdd_options) {
        this.network = network.nodes;
    }
    this(CreateNetworkWithNAmountOfNodesInModezero network, BDDOptions bdd_options) {
        this.network = network.nodes;
        this.bdd_options = bdd_options;
    }

    @Given("i have a network with pids of the processes.")
    Document processes() {
        return result_ok;
    }

    @When("i send two kill commands.")
    Document commands() @trusted {

        if (bdd_options.network.mode == 1 ) {
            foreach(node; network) {
                writefln("%s", node.pid.processID);
                kill(node.pid, SIGKILL);
                Thread.sleep(100.msecs);
                kill(node.pid, SIGKILL);
                wait(node.pid);
            }  
        } else {
            auto node = network[$-1];
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
