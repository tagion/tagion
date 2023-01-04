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
import tagion.testbench.transaction_features.create_wallets;
import tagion.testbench.tools.utils : Genesis;
import tagion.testbench.transaction_features.create_network;

enum feature = Feature("Generate transaction", []);

alias FeatureContext = Tuple!(CreateTransaction, "CreateTransaction", FeatureGroup*, "result");



@safe @Scenario("Create transaction", [])
class CreateTransaction {

    CreateNetworkWithNAmountOfNodesInModeone network;
    GenerateNWallets wallets;
    const Genesis[] genesis;
    string module_path;

    this(string module_name, GenerateNWallets wallets, CreateNetworkWithNAmountOfNodesInModeone network, const Genesis[] genesis)
    {
        this.wallets = wallets;
        this.genesis = genesis;
        this.module_path = env.bdd_log.buildPath(module_name);
        this.network = network;
    }

    @Given("a network.")
    Document _network() {
        
        return Document();
    }

    @Given("the network have a wallet A with tagions.")
    Document tagions() {
        return Document();
    }

    @Given("the wallets have an invoice in another_wallet.")
    Document anotherwallet() {
        return Document();
    }

    @When("wallet A pays the invoice.")
    Document invoice() {
        return Document();
    }

    @When("the contract is executed.")
    Document executed() {
        return Document();
    }

    @Then("the balance should be checked against all nodes.")
    Document nodes() {
        return Document();
    }

    @Then("wallet B should receive the invoice amount.")
    Document amount() {
        return Document();
    }

    @Then("wallet A should loose invoice amount + fee.")
    Document fee() {
        return Document();
    }

    @Then("the bullseye of all the nodes DARTs should be the same.")
    Document same() {
        return Document();
    }

    @But("the transaction should not take longer than Tmax seconds.")
    Document seconds() {
        return Document();
    }

    @But("the transaction should finish in 8 epochs.")
    Document epochs() {
        return Document();
    }

}
