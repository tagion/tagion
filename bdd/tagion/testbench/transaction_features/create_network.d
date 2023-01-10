module tagion.testbench.transaction_features.create_network;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import std.stdio;
import std.process;
import std.path;
import std.string;
import std.array;
import std.file;
import std.conv;
import core.thread;
import std.algorithm;

import tagion.testbench.transaction_features.create_wallets;
import tagion.testbench.transaction_features.create_dart;
import tagion.testbench.tools.utils : Genesis;
import tagion.testbench.tools.wallet;
import tagion.testbench.tools.network;

enum feature = Feature("Start network", []);

alias FeatureContext = Tuple!(CreateNetworkWithNAmountOfNodesInModeone, "CreateNetworkWithNAmountOfNodesInModeone",
    FeatureGroup*, "result");

@safe @Scenario("Create network with n amount of nodes in mode_one", [])
class CreateNetworkWithNAmountOfNodesInModeone
{

    GenerateDart dart;
    TagionWallet[] wallets;
    const Genesis[] genesis;
    const int number_of_nodes;
    string module_path;

    Node[] nodes;
    string[] node_logs;
    string[] node_darts;

    this(string module_name, GenerateDart dart, GenerateNWallets genWallets, const Genesis[] genesis, const int number_of_nodes)
    {
        this.dart = dart;
        this.wallets = genWallets.wallets;
        this.genesis = genesis;
        this.number_of_nodes = number_of_nodes;
        this.module_path = env.bdd_log.buildPath(module_name);
    }

    @Given("i have _wallets")
    Document _wallets()
    {
        check(wallets !is null, "No wallets available");

        return result_ok;
    }

    @Given("i have a dart with a genesis_block")
    Document genesisblock()
    {
        check(dart.dart_path.exists, "dart not found");
        check(dart.genesis_path.exists, "genesis not found");
        return result_ok;
    }

    @When("network is started")
    Document started() @trusted
    {

        // start all normal nodes
        for (int i = 1; i < number_of_nodes; i++)
        {
            Node node = Node(module_path, i, number_of_nodes);
            nodes ~= node;
        }

        Node node = Node(module_path, number_of_nodes, number_of_nodes, true);
        nodes ~= node;

        return result_ok;
    }

    @Then("the nodes should be in_graph")
    Document ingraph() @trusted
    {
        int sleep_before = 5;
        Thread.sleep(sleep_before.seconds);
        check(waitUntilInGraph(60, 1, "10801") == true, "in_graph not found in log");

        return result_ok;
    }

    @Then("the wallets should receive genesis amount")
    Document amount() @trusted
    {
        foreach (i, genesis_amount; genesis)
        {
            /* immutable cmd = wallets[i].update(); */
            /* check(cmd.status == 0, format("Error: %s", cmd.output)); */

            Balance balance = wallets[i].getBalance();
            check(balance.returnCode == true, "Error in updating balance");
            writefln("%s", balance);
            check(balance.total == genesis[i].amount, "Balance not updated");
        }
        // check that wallets were updated correctly
        return result_ok;
    }

}
