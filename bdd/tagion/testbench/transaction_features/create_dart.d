module tagion.testbench.transaction_features.create_dart;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;

import std.typecons : Tuple;
import std.stdio;
import std.process;
import std.path;
import std.string;
import std.array;
import std.file;

import tagion.testbench.tools.Environment;
import tagion.testbench.transaction_features.create_wallets;
import tagion.testbench.tools.utils: Genesis;

enum feature = Feature(
            "Add genesis wallets.",
            []);

alias FeatureContext = Tuple!(
        GenerateDartboot, "GenerateDartboot",
        FeatureGroup*, "result"
);

@safe @Scenario("Generate dartboot.",
        [])
class GenerateDartboot {

    string dart_path;
    string genesis_path;
    string module_path;
    GenerateNWallets wallets;
    Genesis[] genesis;
    this(string name, GenerateNWallets wallets, Genesis[] genesis) {
        this.wallets = wallets;
        this.genesis = genesis;
        this.module_path = env.bdd_log.buildPath(module_name);
    }
    @Given("I have wallets with pincodes")
    Document pincodes() {
        check(wallet_paths !is null, "No wallets available");

        return result_ok;
    }

    @Given("I initialize a Dart")
    Document dart() @trusted {
        dart_path = env.bdd_log.buildPath(module_path, "dart.drt");

        immutable dart_init_command = [
            tools.dartutil,
            "--initialize",
            "--dartfilename",
            dart_path
        ];

        auto init_dart_pipe = pipeProcess(dart_init_command, Redirect.all, null, Config.detached, module_path);
        writefln("%s", init_dart_pipe.stdout.byLine);
        
        check(dart_path.exists, "Dart not created");

        return result_ok;

    }

    @When("I add genesis invoice to N wallet")
    Document wallet() {
        foreach(i, genesis_invoice; genesis) {
            const invoice_path = buildPath(wallets.wallet_paths[i], "invoice_file.hibon");
            genesis_path = buildPath(wallets.wallet_paths[i], "genesis.hibon");
            writefln("invoice path: %s", invoice_path);

            immutable create_invoice_command = [
                tools.tagionwallet,
                "--create-invoice",
                "GENESIS:100000",
                "--invoice",
                invoice_path,
                "-x",
                "1111",
            ];

            auto create_invoice_pipe = pipeProcess(create_invoice_command, Redirect.all, null, Config
                    .detached, wallets.wallet_paths[i],);
            writeln(create_invoice_pipe.stdout.byLine);

            immutable boot_command = [
                tools.tagionboot,
                invoice_path,
                "-o",
                genesis_path,
            ];

            auto boot_pipe = pipeProcess(boot_command, Redirect.all, null, Config.detached);

            writefln("%s", boot_pipe.stdout.byLine);

            check(genesis_path.exists, "Genesis file not created");

            immutable dart_input_command = [
                tools.dartutil,
                "--dartfilename",
                dart_path,
                "--modify",
                "--inputfile",
                genesis_path,
            ];

            writefln("%s", dart_input_command.join(" "));

            auto dart_input_pipe = pipeProcess(dart_input_command, Redirect.all, null, Config.detached);
            writefln("%s", dart_input_pipe.stdout.byLine);
        }
    return result_ok;
    }


    @Then("the dartboot should be generated")
    Document generated() {
        return Document();
    }

}
