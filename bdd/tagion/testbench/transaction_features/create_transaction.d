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
import std.algorithm;

import tagion.testbench.tools.Environment;
import tagion.testbench.tools.FileName : generateFileName;

import tagion.testbench.transaction_features.create_wallets;
import tagion.testbench.tools.utils : Genesis;
import tagion.testbench.transaction_features.create_network;
import tagion.testbench.tools.network;
import tagion.testbench.tools.wallet;

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
    int start_epoch;
    int end_epoch;

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

        invoice_path = wallets[1].createInvoice("INVOICE", invoice_amount);
        writefln("invoice path: %s", invoice_path);

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
        start_epoch = getEpoch("10801");
        writefln("startepoch %s", start_epoch);

        return result_ok;
    }

    @When("the contract is executed.")
    Document executed()
    {
        check(waitUntilLog(60, 1, "Executing contract", network.node_logs[$-1]) == true, "Executing contract not found in log");
        end_epoch = getEpoch("10801");
        return result_ok;
    }

    @Then("the balance should be checked against all nodes.")
    Document nodes()
    {
        wallet_0 = wallets[0].getBalance();
        wallet_1 = wallets[1].getBalance();

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
    Document same() @trusted
    {
        string[] bullseyes;
        foreach(i, dart_path; network.node_darts) {
            bullseyes ~= getBullseye(dart_path);
        }
        foreach(bullseye; bullseyes) {
            writeln(bullseye);
        }


        check(checkBullseyes(bullseyes) == true, "Bullseyes not the same on all nodes");
        return result_ok;
    }

    @But("the transaction should not take longer than Tmax seconds.")
    Document seconds()
    {
        // waituntillog fails if it takes longer
        return result_ok;
    }

    @But("the transaction should finish in 8 epochs.")
    Document epochs()
    {
        const delta_epoch = end_epoch - start_epoch;
        check(delta_epoch < 8, format("Transaction took too many epochs. Took %s", delta_epoch));
        return result_ok;
    }

}
