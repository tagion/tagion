module tagion.testbench.functional.create_network_in_mode_zero;
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
import tagion.testbench.functional.create_wallets;
import tagion.testbench.functional.create_dart;
import tagion.testbench.tools.utils : Genesis;
import tagion.testbench.tools.wallet;
import tagion.testbench.tools.network;
import tagion.testbench.tools.BDDOptions;


enum feature = Feature(
    "Start network in mode zero",
    []);

alias FeatureContext = Tuple!(
    CreateNetworkWithNAmountOfNodesInModezero, "CreateNetworkWithNAmountOfNodesInModezero",
FeatureGroup*, "result"
);


@safe @Scenario("Create network with n amount of nodes in mode_zero",
[])
class CreateNetworkWithNAmountOfNodesInModezero {

    GenerateDart dart;
    TagionWallet[] wallets;
    const Genesis[] genesis;
    const int number_of_nodes;
    string module_path;

    Node[] nodes;
    string[] node_logs;
    string[] node_darts;

    uint increase_port;
    uint tx_increase_port;

    this(GenerateDart dart, GenerateNWallets genWallets, BDDOptions bdd_options) {
        this.dart = dart;
        this.wallets = genWallets.wallets;
        this.genesis = bdd_options.genesis_wallets.wallets;
        this.number_of_nodes = bdd_options.network.number_of_nodes;
        this.module_path = env.bdd_log.buildPath(bdd_options.scenario_name);
        this.increase_port = bdd_options.network.increase_port;
        this.tx_increase_port = bdd_options.network.tx_increase_port;

    }

    @Given("i have _wallets")
    Document _wallets() {
        check(wallets !is null, "No wallets available");

        return result_ok;
    }

    @Given("i have a dart with a genesis_block")
    Document genesisblock() {
        check(dart.dart_path.exists, "dart not found");
        check(dart.genesis_path.exists, "genesis not found");
        return result_ok;
    }

    @When("network is started")
    Document started() @trusted {
        
        writefln("DART_PATH: %s", dart.dart_path);
        writefln("FOLDER with DART: %s", module_path.buildPath("network", "data"));

        auto args = ["tagionwave", "-N", "7", "--dart-filename", dart.dart_path, "-t", "200", "--dart-init=false", "--logger-filename=tinynet.log"];
        // pipeProcess(args, Redirect.all, null, Config.detached, module_path.buildPath("network", "data"));
        // executeShell(args, null, Config.detached, 18446744073709551615LU, module_path.buildPath("network", "data"));
        /* nodes ~= new Node(module_path, number_of_nodes, number_of_nodes, increase_port, tx_increase_port, true, "internal", dart.dart_path); */
        auto f = File("/dev/null", "w");
        auto pid = spawnProcess(args, std.stdio.stdin, f, f, null, Config.none, module_path.buildPath("network", "data"));
        return result_ok;
        
    }

    @Then("the nodes should be in_graph")
    Document ingraph() @trusted {

        int sleep_before = 30;
        Thread.sleep(sleep_before.seconds);
        check(waitUntilInGraph(60, 1, 10800) == true, "in_graph not found in log");

        return result_ok;
    }

    @Then("the wallets should receive genesis amount")
    Document amount() {
        return result_ok;
    }

}
            
