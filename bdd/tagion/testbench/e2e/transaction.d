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

import tagion.tools.shell.shelloptions;
import tagion.services.options;
import std.process;

import tagion.testbench.e2e;

enum feature = Feature(
            "Send a contract through the shell",
            []);

alias FeatureContext = Tuple!(
        SendAContractWithOneOutputsThroughTheShell, "SendAContractWithOneOutputsThroughTheShell",
        FeatureGroup*, "result"
);

void wrap_shell(immutable(string[]) args) {
    import tagionshell = tagion.tools.tagionshell;
    tagionshell._main(cast(string[]) args);
}
void wrap_neuewelle(immutable(string)[] args) {
    neuewelle._main(cast(string[]) args);
}

mixin Main!(_main);
int _main(string[] args) {

    auto module_path = env.bdd_log.buildPath(__MODULE__);
    if (module_path.exists) { rmdirRecurse(module_path); }
    mkdirRecurse(module_path);
    const shell_config_file = buildPath(module_path, "shell.json");
    const config_file = buildPath(module_path, "tagionwave.json");


    scope ShellOptions shell_opts = ShellOptions.defaultOptions;
    shell_opts.shell_uri = environment["SHELL_URI"];
    shell_opts.save(shell_config_file);
    
    scope Options local_options = Options.defaultOptions;
    local_options.dart.folder_path = buildPath(module_path);
    local_options.trt.folder_path = buildPath(module_path);
    local_options.trt.enable = true;
    local_options.replicator.folder_path = buildPath(module_path, "recorders");
    local_options.epoch_creator.timeout = 250;
    local_options.wave.prefix_format = "TRT_TEST_Node_%s_";
    local_options.subscription.address = contract_sock_addr("TRT_TEST_SUBSCRIPTION");
    local_options.save(config_file);

    immutable(string[]) shell_args = ["tagionshell_transaction", shell_config_file];
    auto tid = spawn(&wrap_shell, shell_args);

    Thread.sleep(20.seconds);
    
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
