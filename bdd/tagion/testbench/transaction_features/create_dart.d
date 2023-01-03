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
import tagion.testbench.extras.utils: Genesis;

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
        return Document();
    }

    @Then("the dartboot should be generated")
    Document generated() {
        return Document();
    }

}
