module tagion.testbench.functional.receive_epoch_test;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;

import tagion.testbench.tools.network;
import tagion.testbench.functional.create_network;
import tagion.testbench.tools.BDDOptions;

import std.datetime;
import std.process;
import core.thread;
import std.stdio;
import std.range;
import std.conv;
import std.file: exists;

enum feature = Feature(
        "Check for received epoch",
        []);

alias FeatureContext = Tuple!(
    Receivedepoch, "Receiveepoch",
    FeatureGroup*, "result"
);

@safe @Scenario("receive_epoch_test", [])
class Receivedepoch
{
    Node[] network;
    BDDOptions bdd_options;
    string node_log_path;

    this(CreateNetworkWithNAmountOfNodesInModeone network, BDDOptions bdd_options)
    {
        this.network = network.nodes;
        this.bdd_options = bdd_options;
    }

    @Given("a network.")
    Document _network()
    {
        node_log_path = network[$-1].logger_file;
        check(node_log_path.exists, "node log file not found");

        return result_ok;
    }

    @When("i continously check if the node log contains received epoch")
    Document epoch() @trusted
    {
        const end = Clock.currTime() + dur!"seconds"(30);

        auto node_log = File(node_log_path, "r");
        scope(exit){
            node_log.close();
        }

        foreach(line; node_log.byLine) {
            if (Clock.currTime() > end) {
                break;
            }
            writefln("%s", line);
        }


        // immutable grep_command = [
        //     "grep",
        //     "Received epoch",
        //     node_log_path,
        //     "|",
        //     "tail",
        //     "-1",
        // ];
        // auto node_pipe = pipeProcess(grep_command, Redirect.all, null, Config
        //         .detached);

        
        Thread.sleep(5.seconds);
        return result_ok;
    }

    @Then("the pattern should be found")
    Document found()
    {
        return Document();
    }

}
