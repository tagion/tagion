module tagion.testbench.functional.create_double_spend;
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
import core.thread;
import core.time;
import std.math.operations : approxEqual;


import tagion.testbench.tools.Environment;

import tagion.testbench.functional.create_wallets;
import tagion.testbench.tools.utils : Genesis;
import tagion.testbench.functional.create_network_in_mode_one;
import tagion.testbench.functional.create_transaction;
import tagion.testbench.tools.network;
import tagion.testbench.tools.wallet;
import tagion.testbench.tools.BDDOptions;

enum feature = Feature("Verify that double spend cant occur", []);

alias FeatureContext = Tuple!(DoubleSpendSameWallet, "DoubleSpendSameWallet", FeatureGroup*, "result");

@safe @Scenario("Double spend same wallet", [])
class DoubleSpendSameWallet
{

    Node[] network;
    TagionWallet[] wallets;
    const Genesis[] genesis;
    CreateTransaction transaction;
    string module_path;
    string invoice_path_A;
    string invoice_path_B;
    const double invoice_amount = 1000;
    int start_epoch;
    int end_epoch;

    uint increase_port;
    uint tx_increase_port;

    Balance wallet_0;
    Balance wallet_1;

    this(GenerateNWallets genWallets, CreateNetworkWithNAmountOfNodesInModeone network, BDDOptions bdd_options)
    {
        this.wallets = genWallets.wallets;
        this.genesis = bdd_options.genesis_wallets.wallets;
        this.module_path = env.bdd_log.buildPath(bdd_options.scenario_name);
        this.network = network.nodes;
        this.increase_port = bdd_options.network.increase_port;
        this.tx_increase_port = bdd_options.network.tx_increase_port;
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

    @Given("wallet A has two invoices with same input bill to wallet_b.")
    Document walletb() @trusted
    {
        invoice_path_A = wallets[1].createInvoice("INVOICE", invoice_amount);
        invoice_path_B = wallets[1].createInvoice("INVOICE2", invoice_amount);
        writefln("%s -%s", invoice_path_A, invoice_path_B);
        return result_ok;
    }

    @When("wallet A pays both the invoices.")
    Document invoices() @trusted
    {
        wallets[0].payInvoice(invoice_path_A, tx_increase_port + 1);
        wallets[0].unlock(tx_increase_port + 1);
        wallets[0].payInvoice(invoice_path_B, tx_increase_port + 1);
        start_epoch = getEpoch(tx_increase_port + 1);
        return result_ok;
    }

    @When("the contract is executed.")
    Document executed() @trusted
    {
        check(waitUntilLog(60, 1, "Executing contract", network[$ - 1].logger_file) == true, "Executing contract not found in log");
        end_epoch = getEpoch(tx_increase_port + 1);
        Thread.sleep(30.seconds);
        return result_ok;
    }

    @Then("the balance should be checked against all nodes.")
    Document nodes() @trusted
    {
        wallet_0 = wallets[0].getBalance(tx_increase_port + 1);
        wallet_1 = wallets[1].getBalance(tx_increase_port + 1);

        check(wallet_0.returnCode == true && wallet_1.returnCode == true, "Balances not updated");
        return result_ok;
    }

    @Then("wallet B should only receive the invoice amount.")
    Document amount()
    {
        check(wallet_1.total.approxEqual(genesis[1].amount + invoice_amount) == true, "Balance not correct");
        return result_ok;
    }

    @Then("wallet A should loose invoice amount + fee.")
    Document fee()
    {
        writefln("total: %s, amount: %s", wallet_0.total, genesis[0].amount-invoice_amount-0.1);
        check(wallet_0.total.approxEqual(genesis[0].amount-invoice_amount-0.1) == true, "Balance not correct");
        return result_ok;
    }

    @Then("the bullseye of all the nodes DARTs should be the same.")
    Document same() @trusted
    {
        string[] bullseyes;
        foreach (node; network)
        {
            bullseyes ~= getBullseye(node.dart_path);
        }
        foreach (bullseye; bullseyes)
        {
            writeln(bullseye);
        }

        check(checkBullseyes(bullseyes) == true, "Bullseyes not the same on all nodes");
        return result_ok;
    }

    @But("the transaction should not take longer than Tmax seconds.")
    Document seconds()
    {
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
