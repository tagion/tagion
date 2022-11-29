module tagion.testbench.wallet.Start_network;

import std.stdio;
import std.process;
import std.typecons : Tuple;
import std.path;
import std.string;
import std.array;
import std.file;

// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.Environment;
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
            // writeln(node_dart);
            // writefln("--boot=%s", boot_file_path);
            // writefln("--dart-path=%s", node_dart);
            // writefln("--port=%s", 4000 + i);
            // writefln("--transaction-port=%s", 10800 + i);
            // writefln("--logger-filename=node-%s.log", i);
            immutable node_command = [
                "screen",
                "-S",
                "testnet",
                "-dm",
                tools.tagionwave,
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
            tools.tagionwave,
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
        auto node_master_pipe = pipeProcess(node_master_command, Redirect.all, null, Config.detached);
        writefln("%s", node_master_pipe.stdout.byLine);

        return result_ok;
    }

    @Then("the nodes should be in_graph")
    Document ingraph()
    {

        return Document();
    }

    @Then("one wallet should receive genesis amount")
    Document amount()
    {
        return Document();
    }
}
