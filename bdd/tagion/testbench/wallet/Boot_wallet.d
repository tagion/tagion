module tagion.testbench.wallet.Boot_wallet;

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
import tagion.testbench.wallet.Wallet_generation;
import tagion.testbench.tools.Environment;

enum feature = Feature("Add genesis wallets.", []);

alias FeatureContext = Tuple!(GenerateDartboot, "GenerateDartboot", FeatureGroup*, "result");

@safe @Scenario("Generate dartboot.", [])
class GenerateDartboot
{
    string genesis_path;
    string dart_path;

    SevenWalletsWillBeGenerated wallets;
    this(SevenWalletsWillBeGenerated wallets)
    {
        this.wallets = wallets;
    }

    @Given("I have wallets with pincodes")
    Document pincodes()
    {
        check(wallets !is null, "No wallets available");

        return result_ok;
    }

    @Given("I initialize a Dart")
    Document dart() @trusted {
        dart_path = env.bdd_log.buildPath("dart.drt");

        immutable dart_init_command = [
            tools.dartutil,
            "--initialize",
            "--dartfilename",
            dart_path
        ];

        auto init_dart_pipe = pipeProcess(dart_init_command, Redirect.all, null, Config.detached);
        writefln("%s", init_dart_pipe.stdout.byLine);
        
        check(dart_path.exists, "Dart not created");

        return result_ok;

    }

    @When("I add genesis invoice to one wallet")
    Document wallet() @trusted
    {
        const invoice_path = buildPath(wallets.wallet_paths[0], "invoice_file.hibon");
        genesis_path = buildPath(wallets.wallet_paths[0], "genesis.hibon");
        writefln("invoice path: %s", invoice_path);

        immutable create_invoice_command = [
            tools.tagionwallet,
            "--create-invoice",
            "GENESIS:100000",
            "--invoice",
            invoice_path,
            "-x",
            wallets.pin_array[0],
            wallets.wallets[0],
        ];

        auto create_invoice_pipe = pipeProcess(create_invoice_command, Redirect.all, null, Config
                .detached);
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

        return result_ok;
    }

    @Then("the dartboot should be generated")
    Document generated() @trusted
    {
        // do some sort of check that checks if the dartboot has been succesfully created.
        return result_ok;

    }

}
