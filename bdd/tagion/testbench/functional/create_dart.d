module tagion.testbench.functional.create_dart;
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
import tagion.testbench.tools.wallet;
import tagion.testbench.functional.create_wallets;
import tagion.testbench.tools.utils : Genesis;
import tagion.testbench.tools.FileName : generateFileName;
import tagion.testbench.tools.BDDOptions;

enum feature = Feature(
        "Add genesis wallets.",
        []);

alias FeatureContext = Tuple!(
    GenerateDart, "GenerateDart",
    FeatureGroup*, "result"
);

@safe @Scenario("Generate dart.",
    [])
class GenerateDart
{

    string dart_path;
    string genesis_path;
    string module_path;
    TagionWallet[] wallets;
    const Genesis[] genesis;
    string[] invoices;

    this(GenerateNWallets genWallets, BDDOptions bdd_options)
    {
        this.wallets = genWallets.wallets;
        this.genesis = bdd_options.genesis_wallets.wallets;
        this.module_path = env.bdd_log.buildPath(bdd_options.scenario_name);
    }

    @Given("I have wallets with pincodes")
    Document pincodes()
    {
        check(wallets !is null, "No wallets available");

        return result_ok;
    }

    @Given("I initialize a Dart")
    Document dart() @trusted
    {
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
    Document wallet() @trusted
    {
        foreach (i, genesis_invoice; genesis)
        {
            if (genesis_invoice.amount == 0) {
                continue;
            }
            const amountPerBill = genesis_invoice.amount / genesis_invoice.bills;
            writefln("wallet %s", wallets[i].path);

            writefln("GENESIS BILLS AMOUNT: %s", genesis_invoice.bills);
            for (int bill = 0; bill < genesis_invoice.bills; bill++)
            {
                writefln("bill %s", bill);
                const invoice_path = wallets[i].createInvoice("GENESIS", amountPerBill);
                invoices ~= invoice_path;
            }

        }

        return result_ok;
    }

    @Then("the dart should be generated")
    Document generated() @trusted
    {
        genesis_path = buildPath(module_path, "genesis.hibon");

        foreach (i, invoice; invoices)
        {
            immutable boot_command = [
                tools.tagionboot,
                invoice,
                "-o",
                genesis_path,
            ];
            auto boot_pipe = pipeProcess(boot_command, Redirect.all, null, Config.detached);
            writefln("%s", boot_pipe.stdout.byLine);

            immutable dart_input_command = [
                tools.dartutil,
                "--dartfilename",
                dart_path,
                "--modify",
                "--inputfile",
                genesis_path,
            ];

            writefln("%s", dart_input_command.join(" "));

            auto dart_input_pipe = pipeProcess(dart_input_command, Redirect.all, null, Config
                    .detached);
            writefln("%s", dart_input_pipe.stdout.byLine);

        }

        check(genesis_path.exists, "Genesis file not created");

        // verify that everything looks correct.
        return result_ok;
    }

}
