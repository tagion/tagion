module tagion.testbench.e2e.operational;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import tagion.tools.Basic;

import std.format;
import std.algorithm;
import std.range;
import std.stdio;
import std.path;
import std.getopt;
import std.file;

import tagion.tools.wallet.WalletOptions : WalletOptions;
import tagion.tools.wallet.WalletInterface;
import tagion.script.common;
import tagion.script.TagionCurrency;
import tagion.communication.HiRPC;

alias operational = tagion.testbench.e2e.operational;

mixin Main!(_main);

int _main(string[] args) {
    const program = args[0];
    string[] wallet_config_files;
    string[] wallet_pins;
    bool sendkernel = false;

    arraySep = ",";
    auto main_args = getopt(args,
            "w", "wallet config files", &wallet_config_files,
            "x", "wallet pins", &wallet_pins,
            "sendkernel", "Send requests directory to the kernel", &sendkernel, // "n", "network config file", &network_config,

            

    );

    if (main_args.helpWanted) {
        defaultGetoptPrinter(
                [
            "Usage:",
            format("%s [<option>...] <config.json> <files>", program),
            "<option>:",
        ].join("\n"),
                main_args.options);
        return 0;
    }

    import std.process : environment;

    const HOME = environment.get("HOME");
    if (wallet_config_files.empty) {
        wallet_config_files = dirEntries(buildPath(HOME, ".local/share/tagion/wallets/"), "wallet*.json", SpanMode
                .shallow).map!(a => a.name).array.sort.array;
        if (wallet_config_files.empty) {
            writeln("No wallet configs available");
            return 0;
        }
    }

    if (wallet_pins.empty) {
        foreach (i, _; wallet_config_files) {
            wallet_pins ~= format("%04d", i + 1);
        }
    }

    check(wallet_pins.length == wallet_config_files.length, "wallet configs and wallet pins were not the same amount");

    WalletOptions[] wallet_options;
    WalletInterface[] wallet_interfaces;
    foreach (i, c; wallet_config_files) {
        WalletOptions opts;
        opts.load(c);
        wallet_options ~= opts;
        auto wallet_interface = WalletInterface(opts);
        check(wallet_interface.load, "Wallet %s could not be loaded".format(i));
        check(wallet_interface.secure_wallet.login(wallet_pins[i]), "Wallet %s, %s, %s not logged in".format(i, wallet_pins[i], c));
        wallet_interfaces ~= wallet_interface;
        writefln("Wallet logged in %s", wallet_interface.secure_wallet.isLoggedin);
    }

    auto manycontracts_feature = automation!operational;
    manycontracts_feature.SendNContractsFromwallet1Towallet2(wallet_interfaces, sendkernel);
    manycontracts_feature.run;
    return 1;
}

enum feature = Feature(
            "send multiple contracts through the network",
            []);

alias FeatureContext = Tuple!(
        SendNContractsFromwallet1Towallet2, "SendNContractsFromwallet1Towallet2",
        FeatureGroup*, "result"
);

@safe @Scenario("send N contracts from `wallet1` to `wallet2`",
        [])
class SendNContractsFromwallet1Towallet2 {
    WalletInterface[] wallets;
    bool sendkernel;

    bool send;
    this(WalletInterface[] wallets, bool sendkernel
    ) {
        this.wallets = wallets;
        this.sendkernel = sendkernel;
        this.send = !sendkernel;
    }

    @Given("i have a network")
    Document network() @trusted {
        const wallet_switch = WalletInterface.Switch(update : true, sendkernel:
                sendkernel, send:
                send);

        foreach (ref w; wallets[0 .. 2]) {
            w.operate(wallet_switch, []);
        }

        return result_ok;
    }

    @When("i send N many valid contracts from `wallet1` to `wallet2`")
    Document wallet2() @trusted {
        const invoice = wallets[0].secure_wallet.createInvoice("Invoice", 1000.TGN);

        SignedContract signed_contract;
        TagionCurrency fees;

        with (wallets[1]) {
            auto result = secure_wallet.payment([invoice], signed_contract, fees);

            const message = secure_wallet.net.calcHash(signed_contract);
            const contract_net = secure_wallet.net.derive(message);
            const hirpc = HiRPC(contract_net);
            const hirpc_submit = hirpc.submit(signed_contract);

            sendSubmitHiRPC(options.contract_address, hirpc_submit, contract_net);

            result.get;
        }

        return result_ok;
    }

    @When("all the contracts have been executed")
    Document executed() @trusted {
        import core.time;
        import core.thread;

        Thread.sleep(5.seconds);
        return result_ok;
    }

    @Then("wallet1 and wallet2 balances should be updated")
    Document updated() @trusted {
        const wallet_switch = WalletInterface.Switch(
    trt_update : true,
    sendkernel:
                sendkernel,
    send:
                send);

        foreach (ref w; wallets[0 .. 2]) {
            w.operate(wallet_switch, []);
        }
        return result_ok;
    }

}
