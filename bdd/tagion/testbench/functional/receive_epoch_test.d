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
import std.format;
import std.string;

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
    int time_between_new_epocs;
    int duration_seconds;

    this(CreateNetworkWithNAmountOfNodesInModeone network, BDDOptions bdd_options)
    {
        this.network = network.nodes;
        this.time_between_new_epocs = bdd_options.epoch_test.time_between_new_epocs;
        this.duration_seconds = bdd_options.epoch_test.duration_seconds;
    }

    @Given("a network.")
    Document _network() @trusted
    {
        Thread.sleep(5.seconds);
        node_log_path = network[$-1].logger_file;
        check(node_log_path.exists, "node log file not found");

        return result_ok;
    }

    @When("i continously check if the node log contains received epoch")
    Document epoch() @trusted
    {
        const end = Clock.currTime() + dur!"seconds"(duration_seconds);
        auto interval = Clock.currTime() + dur!"seconds"(time_between_new_epocs);
        int received_epochs = 0;


        /* foreach (line; network[0].ps.stdout.byLine) { */
        /*         writeln("Node 0 log :: %s", line); */
        /* } */

        immutable string grep_command = format("grep 'Received epoch' %s | wc -l", node_log_path);
        while(Clock.currTime() < end) {

            auto last_message = executeShell(grep_command);

            last_message.output.writeln;
            if (last_message.status != 0) {
                writefln("came to here");
                continue;
            } else {
                const int number_of_received_epochs = last_message.output.strip.to!int;
                if (received_epochs < number_of_received_epochs) {
                    received_epochs = number_of_received_epochs;
                    interval = Clock.currTime() + dur!"seconds"(time_between_new_epocs);
                }
            }

            check(interval > Clock.currTime(), format("Epoch not received for %s seconds", time_between_new_epocs));
            Thread.sleep(1.seconds);
        }

        return result_ok;
    }

    @Then("the pattern should be found")
    Document found()
    {
        return result_ok;
    }

}
