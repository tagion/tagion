module tagion.testbench.wallet.Start_network;

import std.stdio;
import std.process;
import std.typecons : Tuple;
import std.path;
import std.string;
import std.array;
import std.file;
import core.thread;

// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;
import tagion.testbench.wallet.Wallet_generation;
import tagion.testbench.wallet.Boot_wallet;

enum feature = Feature("Start network", []);

alias FeatureContext = Tuple!(StartNetworkInModeone, "StartNetworkInModeone", FeatureGroup*, "result");

@safe @Scenario("Start network in mode_one", [])
class StartNetworkInModeone
{

    SevenWalletsWillBeGenerated wallets;
    GenerateDartboot dart;
    const number_of_nodes = 7;
    string[] node_logs;
    string[] node_darts;
    const tagionwave = "/home/imrying/bin/tagionwave";

    this(SevenWalletsWillBeGenerated wallets, GenerateDartboot dart)
    {
        this.wallets = wallets;
        this.dart = dart;
    }

    @Given("i have wallets with pincodes")
    Document pincodes()
    {
        check(wallets !is null, "No wallets available");

        return result_ok;
    }

    @Given("i have a dart with genesis block")
    Document block()
    {
        check(dart.dart_path.exists, "Dart not created");
        return result_ok;
    }

    @When("network is started")
    Document started() @trusted
    {
        const boot_file_path = env.bdd_log.buildPath("boot.hibon");

        for (int i = 1; i < number_of_nodes; i++)
        {
            immutable node_dart = env.bdd_log.buildPath(format("dart%s.drt", i));
            immutable node_log = env.bdd_log.buildPath(format("node-%s.log", i));
            node_darts ~= node_dart;
            node_logs ~= node_log;

            immutable node_command = [
                "screen",
                "-S",
                "testnet",
                "-dm",
                tagionwave,
                "--net-mode=local",
                format("--boot=%s", boot_file_path),
                "--dart-init=true",
                "--dart-synchronize=true",
                format("--dart-path=%s", node_dart),
                format("--port=%s", 4000 + i),
                format("--transaction-port=%s", 10800 + i),
                format("--logger-filename=%s", node_log),
                "-N",
                "7",
            ];
            auto node_pipe = pipeProcess(node_command, Redirect.all, null, Config.detached);
            writefln("%s", node_pipe.stdout.byLine);
        }
        immutable node_master_log = env.bdd_log.buildPath("node-master.log");
        node_logs ~= node_master_log;
        node_darts ~= dart.dart_path;
        immutable node_master_command = [
            "screen",
            "-S",
            "testnet-master",
            "-dm",
            tagionwave,
            "--net-mode=local",
            format("--boot=%s", boot_file_path),
            "--dart-init=false",
            "--dart-synchronize=false",
            format("--dart-path=%s", dart.dart_path),
            format("--port=%s", 4020),
            format("--transaction-port=%s", 10820),
            format("--logger-filename=%s", node_master_log),
            "-N",
            "7",
        ];
        auto node_master_pipe = pipeProcess(node_master_command, Redirect.all, null, Config
                .detached);
        writefln("%s", node_master_pipe.stdout.byLine);

        return result_ok;
    }

    @Then("the nodes should be in_graph")
    Document ingraph() @trusted
    {
        bool in_graph = false;

        // while (!in_graph)
        // {
        //     immutable health_command = [
        //         tools.tagionwallet,
        //         "--port",
        //         "10801",
        //         "--health"
        //     ];
        //     auto health_pipe = pipeProcess(health_command, Redirect.all, null, Config.detached);
        //     writefln("%s", health_pipe.stdout.byLine);
        //     in_graph = true;
        // }
        return Document();
    }

    @Then("one wallet should receive genesis amount")
    Document amount()
    {
        return Document();
    }
}
