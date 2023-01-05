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
import tagion.testbench.tools.cli;

enum feature = Feature("Generate transaction", []);

alias FeatureContext = Tuple!(CreateTransaction, "CreateTransaction", FeatureGroup*, "result");

@safe @Scenario("Create transaction", [])
class CreateTransaction
{

    CreateNetworkWithNAmountOfNodesInModeone network;
    TagionWallet[] wallets;
    const Genesis[] genesis;
    string module_path;
    string invoice_path;
    const double invoice_amount = 1000;

    Balance wallet_0;
    Balance wallet_1;

    this(string module_name, GenerateNWallets genWallets, CreateNetworkWithNAmountOfNodesInModeone network, const Genesis[] genesis)
    {
        this.wallets = genWallets.wallets;
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
        invoice_path = buildPath(wallets[1].path, format("%s-%s", generateFileName(
                10), "invoice.hibon"));
        writefln("invoice path: %s", invoice_path);

        immutable create_invoice_command = [
            tools.tagionwallet,
            "--create-invoice",
            format("INVOICE:%s", invoice_amount),
            "--invoice",
            invoice_path,
            "-x",
            "1111",
        ];

        auto create_invoice_pipe = pipeProcess(create_invoice_command, Redirect.all, null, Config
                .detached, wallets[1].path,);

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
                .detached, wallets[0].path);

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
        wallet_0 = getBalance(wallets[0].path);
        wallet_1 = getBalance(wallets[1].path);

        check(wallet_0.returnCode == true && wallet_1.returnCode == true, "Balances not updated");
        return result_ok;
    }

    @Then("wallet B should receive the invoice amount.")
    Document amount()
    {
        check(wallet_1.total == genesis[1].amount + invoice_amount, "Balance not correct");
        return result_ok;
    }

    @Then("wallet A should loose invoice amount + fee.")
    Document fee()
    {
        check(wallet_0.total == genesis[0].amount - invoice_amount - 0.1, "Balance not correct");
        return result_ok;
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
