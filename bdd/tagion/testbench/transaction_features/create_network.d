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
import tagion.testbench.tools.networkcli;


enum feature = Feature("Start network", []);

alias FeatureContext = Tuple!(CreateNetworkWithNAmountOfNodesInModeone, "CreateNetworkWithNAmountOfNodesInModeone",
    FeatureGroup*, "result");

@safe @Scenario("Create network with n amount of nodes in mode_one", [])
class CreateNetworkWithNAmountOfNodesInModeone
{

    GenerateDart dart;
    GenerateNWallets wallets;
    const Genesis[] genesis;
    const int number_of_nodes;
    string module_path;

    string[] node_logs;
    string[] node_darts;

    this(string module_name, GenerateDart dart, GenerateNWallets wallets, const Genesis[] genesis, const int number_of_nodes)
    {
        this.dart = dart;
        this.wallets = wallets;
        this.genesis = genesis;
        this.number_of_nodes = number_of_nodes;
        this.module_path = env.bdd_log.buildPath(module_name);
    }

    @Given("i have _wallets")
    Document _wallets()
    {
        check(wallets.wallet_paths !is null, "No wallets available");

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
        const boot_path = module_path.buildPath("boot.hibon");

        // start all normal nodes
        for (int i = 1; i < number_of_nodes; i++)
        {
            immutable node_dart = module_path.buildPath(format("dart-%s.drt", i));
            immutable node_log = module_path.buildPath(format("node-%s.log", i));
            node_darts ~= node_dart;
            node_logs ~= node_log;

            immutable node_command = [
                "screen",
                "-S",
                "testnet",
                "-dm",
                tools.tagionwave,
                "--net-mode=local",
                format("--boot=%s", boot_path),
                "--dart-init=true",
                "--dart-synchronize=true",
                format("--dart-path=%s", node_dart),
                format("--port=%s", 4000 + i),
                format("--transaction-port=%s", 10800 + i),
                format("--logger-filename=%s", node_log),
                "-N",
                number_of_nodes.to!string,
            ];

            auto node_pipe = pipeProcess(node_command, Redirect.all, null, Config.detached);
            writefln("%s", node_pipe.stdout.byLine);
        }
        // start master node
        immutable node_master_log = module_path.buildPath("node-master.log");
        node_logs ~= node_master_log;
        node_darts ~= dart.dart_path;

        immutable node_master_command = [
            "screen",
            "-S",
            "testnet-master",
            "-dm",
            tools.tagionwave,
            "--net-mode=local",
            format("--boot=%s", boot_path),
            "--dart-init=false",
            "--dart-synchronize=false",
            format("--dart-path=%s", dart.dart_path),
            format("--port=%s", 4020),
            format("--transaction-port=%s", 10820),
            format("--logger-filename=%s", node_master_log),
            "-N",
            number_of_nodes.to!string,
        ];
        auto node_master_pipe = pipeProcess(node_master_command, Redirect.all, null, Config
                .detached);
        writefln("%s", node_master_pipe.stdout.byLine);

        return result_ok;
    }

    @Then("the nodes should be in_graph")
    Document ingraph() @trusted
    {
        check(waitUntilInGraph(60, 1, "10801") == true, "in_graph not found in log");

        return result_ok;
    }

    @Then("the wallets should receive genesis amount")
    Document amount() @trusted
    {
        foreach(i, genesis_amount; genesis) {
            Balance wallet_balance = getBalance(wallets.wallet_paths[i]);
            check(wallet_balance.returnCode == true, "Error in updating balance");
            writefln("%s", wallet_balance);
            check(wallet_balance.total == genesis[i].amount, "Balance not updated");
        }
        // check that wallets were updated correctly
        return result_ok;
    }

}
