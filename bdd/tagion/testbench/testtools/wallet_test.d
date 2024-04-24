module tagion.testbench.testtools.wallet_test;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import std.format;
import std.file;
import std.path : buildPath;
import std.stdio;

import tagion.tools.Basic;
import tagion.testbench.testtools;
import tagion.behaviour.BehaviourException : check;
import tagion.testbench.testtools.helper_functions;

mixin Main!(_main);

int _main(string[] args) {
    auto module_path = env.bdd_log.buildPath(__MODULE__);
    if (module_path.exists) {
        rmdirRecurse(module_path);
    }
    mkdirRecurse(module_path);

    auto feature = automation!(wallet_test);
    feature.CreateWallet(module_path);
    feature.run;

    return 0;
}

enum feature = Feature(
        "wallet scenarios",
        []);

alias FeatureContext = Tuple!(
    CreateWallet, "CreateWallet",
    FeatureGroup*, "result"
);

@safe @Scenario("CreateWallet",
    [])
class CreateWallet {
    string wallet_folder;
    string wallet_config;

    this(string module_path) {
        this.wallet_folder = module_path ~ "/wallet";
        this.wallet_config = module_path ~ "wallet.json";
    }

    @Given("empty folder for creating a wallet")
    Document wallet() {
        mkdirRecurse(this.wallet_folder);
        check(this.wallet_folder.exists, format("Folder %s not exists", this.wallet_folder));

        return result_ok;
    }

    @When("set wallet folder and config file")
    Document file() {
        execute_tool(ToolName.geldbeutel, [
                "-O", "--path", this.wallet_folder, this.wallet_config
            ]);
        return result_ok;
    }

    @When("set password and pin")
    Document pin() {
        execute_tool(ToolName.geldbeutel, [
                this.wallet_config, "-P", "password", "-x", "0000"
            ]);
        return result_ok;
    }

    @Then("wallet folder should contanin non-empty wallet hibon files")
    Document files() {
        auto device_hibon = this.wallet_folder ~ "/device.hibon";
        auto device_hibon_f = File(device_hibon, "r");
        check(device_hibon.exists && device_hibon_f.size > 0, format("File %s not exists", device_hibon));

        auto wallet_hibon = this.wallet_folder ~ "/wallet.hibon";
        auto wallet_hibon_f = File(wallet_hibon, "r");
        check(wallet_hibon.exists && wallet_hibon_f.size > 0, format("File %s not exists", wallet_hibon));

        return result_ok;
    }
}
