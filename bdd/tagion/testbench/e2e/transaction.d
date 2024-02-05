module tagion.testbench.e2e.transaction;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;
import std.file;
import std.path : buildPath, setExtension;
import tagion.GlobalSignals;
import tagion.basic.Types : FileExtension;
import std.stdio;
import tagion.behaviour.Behaviour;
import tagion.services.options;
import tagion.testbench.services;
import tagion.tools.Basic;
import neuewelle = tagion.tools.neuewelle;
import tagion.utils.pretend_safe_concurrency;
import core.thread;
import core.time;
import tagion.logger.Logger;
import tagion.script.TagionCurrency;
import tagion.script.common;
import tagion.communication.HiRPC;
import tagion.testbench.services.sendcontract;
import tagion.wallet.SecureWallet;
import tagion.testbench.services.helper_functions;
import tagion.behaviour.BehaviourException : check;
import tagion.tools.wallet.WalletInterface;


import tagion.testbench.e2e;

enum feature = Feature(
            "Send a contract through the shell",
            []);

alias FeatureContext = Tuple!(
        SendAContractWithOneOutputsThroughTheShell, "SendAContractWithOneOutputsThroughTheShell",
        FeatureGroup*, "result"
);


mixin Main!(_main);
int _main(string[] args) {
    auto feature = automation!(transaction);
    feature.run;

    return 0;
}

@safe @Scenario("send a contract with one outputs through the shell",
        [])
class SendAContractWithOneOutputsThroughTheShell {

    @Given("i have a running network")
    Document network() {
        return Document();
    }

    @Given("i have a running shell")
    Document shell() {
        return Document();
    }

    @When("i create a contract with all my bills")
    Document bills() {
        return Document();
    }

    @When("i send the contract")
    Document contract() {
        return Document();
    }

    @Then("the transaction should go through")
    Document through() {
        return Document();
    }

}
