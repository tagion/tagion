module tagion.testbench.e2e.remote_sample;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import std.range;

import tagion.testbench.e2e.network;
import tagion.communication.HiRPC;
import tagion.script.common;
import tagion.script.TagionCurrency;
import tagion.tools.wallet.WalletInterface;
import tagion.tools.wallet.WalletOptions;
import tagion.wallet.request;

enum feature = Feature(
            "remote network test",
            []);

alias FeatureContext = Tuple!(
        WeMakeASimpleTransactionOnARemoteNetwork, "WeMakeASimpleTransactionOnARemoteNetwork",
        FeatureGroup*, "result"
);

@safe @Scenario("we make a simple transaction on a remote network",
        [])
class WeMakeASimpleTransactionOnARemoteNetwork {

    WalletInterface wallet_1;
    WalletInterface wallet_2;
    NetworkOptions network_options;

    this(NetworkOptions network_options) {
        this.network_options = network_options;

        check(!network_options.shell_addresses.empty, "No shell address was provided");

        WalletOptions wallet_options;
        wallet_options.setDefault();
        wallet_options.addr = network_options.shell_addresses[0];

        this.wallet_1 = WalletInterface(wallet_options);
        wallet_1.generateSeedFromPassphrase("sample_wallet_1", "0000");

        this.wallet_2 = WalletInterface(wallet_options);
        wallet_2.generateSeedFromPassphrase("sample_wallet_2", "0000");
    }

    @Given("i have 2 wallets a running network and shell")
    Document andShell() {

        check(wallet_1.secure_wallet.isLoggedin, "wallet 1 not logged in");
        check(wallet_2.secure_wallet.isLoggedin, "wallet 2 not logged in");

        return result_ok;
    }

    @When("i make a faucet request on wallet 1")
    @trusted
    Document wallet1() {
        { // Create a faucet request
            WalletInterface.Switch switch_;
            switch_.faucet = true;
            switch_.invoice = "invoice:1000";
            wallet_1.operate(switch_, []);
        }

        // TODO: Wait for transaction to go through

        {
            WalletInterface.Switch switch_;
            switch_.trt_read = true;
            wallet_1.operate(switch_, []);
        }

        return result_ok;
    }

    @When("i send a transaction from wallet 1 to wallet 2")
    Document wallet2() {

        const bill = wallet_2.secure_wallet.requestBill(700.TGN);
        SignedContract s_contract;
        TagionCurrency fees;
        auto result = wallet_1.secure_wallet.createPayment([bill], s_contract, fees);
        result.get(); // unwrap

        HiRPC hirpc = HiRPC(wallet_1.secure_wallet.net);
        const receiver = sendShellHiRPC(wallet_1.options.addr ~ wallet_1.options.hirpc_shell_endpoint, hirpc.submit(s_contract), hirpc);
        check(!receiver.isError, "Got response error when sending submit");

        return result_ok;
    }

    @Then("i expect the transaction to have been executed")
    @trusted
    Document beenExecuted() {

        // TODO: Wait for transaction to go through

        {
            WalletInterface.Switch switch_;
            switch_.trt_read = true;
            wallet_2.operate(switch_, []);
        }

        check(wallet_2.secure_wallet.total_balance == 700.TGN, "Incorrect balance");

        return Document();
    }

}
