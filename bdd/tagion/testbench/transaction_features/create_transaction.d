module tagion.testbench.transaction_features.create_transaction;
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
import std.conv;

import tagion.testbench.tools.Environment;
import tagion.testbench.tools.FileName : generateFileName;

import tagion.testbench.transaction_features.create_wallets;
import tagion.testbench.tools.utils : Genesis;
import tagion.testbench.transaction_features.create_network;
import tagion.testbench.tools.networkcli;

enum feature = Feature("Generate transaction", []);

alias FeatureContext = Tuple!(CreateTransaction, "CreateTransaction", FeatureGroup*, "result");

@safe @Scenario("Create transaction", [])
class CreateTransaction
{

    CreateNetworkWithNAmountOfNodesInModeone network;
    GenerateNWallets wallets;
    const Genesis[] genesis;
    string module_path;
    string invoice_path;

    this(string module_name, GenerateNWallets wallets, CreateNetworkWithNAmountOfNodesInModeone network, const Genesis[] genesis)
    {
        this.wallets = wallets;
        this.genesis = genesis;
        this.module_path = env.bdd_log.buildPath(module_name);
        this.network = network;
    }

    @Given("a network.")
    Document _network()
    {
        return result_ok;

    }

    @Given("the network have a wallet A with tagions.")
    Document tagions()
    {
        return result_ok;
    }

    @Given("the wallets have an invoice in another_wallet.")
    Document anotherwallet() @trusted
    {
        invoice_path = buildPath(wallets.wallet_paths[1], format("%s-%s", generateFileName(
                10), "invoice.hibon"));
        writefln("invoice path: %s", invoice_path);

        immutable create_invoice_command = [
            tools.tagionwallet,
            "--create-invoice",
            format("INVOICE:%s", 1000),
            "--invoice",
            invoice_path,
            "-x",
            "1111",
        ];

        auto create_invoice_pipe = pipeProcess(create_invoice_command, Redirect.all, null, Config
                .detached, wallets.wallet_paths[1],);

        return result_ok;
    }

    @When("wallet A pays the invoice.")
    Document invoice() @trusted
    {

        immutable pay_invoice_command = [
            tools.tagionwallet,
            "-x",
            "1111",
            "--pay",
            invoice_path,
            "--port",
            "10801",
            "--send",
        ];

        auto pay_invoice_pipe = pipeProcess(pay_invoice_command, Redirect.all, null, Config
                .detached, wallets.wallet_paths[0],);

        writefln("%s", pay_invoice_pipe.stdout.byLine);

        return result_ok;
    }

    @When("the contract is executed.")
    Document executed()
    {
        check(waitUntilLog(60, 1, "Executing contract", network.node_logs[$-1]) == true, "Executing contract not found in log");

        return result_ok;
    }

    @Then("the balance should be checked against all nodes.")
    Document nodes()
    {
        return Document();
    }

    @Then("wallet B should receive the invoice amount.")
    Document amount()
    {
        return Document();
    }

    @Then("wallet A should loose invoice amount + fee.")
    Document fee()
    {
        return Document();
    }

    @Then("the bullseye of all the nodes DARTs should be the same.")
    Document same()
    {
        return Document();
    }

    @But("the transaction should not take longer than Tmax seconds.")
    Document seconds()
    {
        return Document();
    }

    @But("the transaction should finish in 8 epochs.")
    Document epochs()
    {
        return Document();
    }

}
