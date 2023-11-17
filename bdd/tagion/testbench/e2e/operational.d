module tagion.testbench.e2e.operational;
// Default import list for bdd
import core.thread;
import core.time;
import std.algorithm;
import std.file;
import std.format;
import std.getopt;
import std.path;
import std.range;
import std.conv;
import std.datetime;
import std.stdio;
import std.random;
import std.typecons : Tuple;
import tagion.behaviour;
import tagion.communication.HiRPC;
import tagion.hibon.Document;
import tagion.hibon.HiBONRecord;
import tagion.script.TagionCurrency;
import tagion.script.common;
import tagion.testbench.tools.Environment;
import tagion.tools.Basic : Main;
import tagion.tools.wallet.WalletInterface;
import tagion.tools.wallet.WalletOptions : WalletOptions;
import tagion.utils.JSONCommon;
import tagion.wallet.AccountDetails;

alias operational = tagion.testbench.e2e.operational;

mixin Main!(_main);

int _main(string[] args) {
    const program = args[0];
    string wallet_configs_path = "~/.local/share/tagion/wallets";
    string[] wallet_pins;
    bool sendkernel = false;

    arraySep = ",";
    auto main_args = getopt(args,
            "w", "wallet configs path files", &wallet_configs_path,
            "x", "wallet pins", &wallet_pins,
            "sendkernel", "Send requests directory to the kernel", &sendkernel,
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
    string[] wallet_config_files = dirEntries(buildPath(HOME, wallet_configs_path), "wallet*.json", SpanMode
            .shallow).map!(a => a.name).array.sort.array;

    if (wallet_config_files.empty) {
        writefln("No wallet configs available in %s", wallet_configs_path);
        return 1;
    }

    if (wallet_pins.empty) {
        foreach (i, _; wallet_config_files) {
            wallet_pins ~= format("%04d", i + 1);
        }
    }

    check(wallet_pins.length == wallet_config_files.length, "wallet configs and wallet pins were not the same amount");

    WalletOptions[] wallet_options;
    WalletInterface*[] wallet_interfaces;
    foreach (i, c; wallet_config_files) {
        WalletOptions opts;
        opts.load(c);
        wallet_options ~= opts;
        auto wallet_interface = new WalletInterface(opts);
        check(wallet_interface.load, "Wallet %s could not be loaded".format(i));
        check(wallet_interface.secure_wallet.login(wallet_pins[i]), "Wallet %s, %s, %s not logged in".format(i, wallet_pins[i], c));
        wallet_interfaces ~= wallet_interface;
        writefln("Wallet logged in %s", wallet_interface.secure_wallet.isLoggedin);
    }

    auto rnd = Random(unpredictableSeed);
    void pickWallets(WalletInterface*[] interfaces, out WalletInterface* wallet1, out WalletInterface* wallet2)
    in (interfaces.length >= 2)
    out (; wallet1 != wallet2)
    do {
        ulong index1 = uniform(0, interfaces.length, rnd);
        ulong index2;
        do {
            index2 = uniform(0, interfaces.length, rnd);
        }
        while (index1 == index2);

        wallet1 = interfaces[index1];
        wallet2 = interfaces[index2];
    }

    // We only want to make one transaction per wallet pair so we can keep track of the balance changes
    const max_concurrent_jobs = (wallet_interfaces.length / 2).to!uint;
    const max_runtime = 3.days;
    // Times of the monotomic clock
    const start_clocktime = MonoTime.currTime;
    const end_clocktime = start_clocktime + max_runtime;

    // Date for pretty reporting
    const start_date = cast(DateTime) Clock.currTime;
    const predicted_end_date = cast(DateTime) Clock.currTime;

    int run_counter;
    scope (exit) {
        const end_date = cast(DateTime)(Clock.currTime);
        writefln("Made %s runs", run_counter);
        writefln("Test ended on %s %s", end_date, end_date);
    }

    writefln("Starting operational test now on\n\t%s\nand will end in %s, on\n\t%s",
            start_date, max_runtime,
            predicted_end_date);

    uint running_jobs;

    bool new_job(ref WalletInterface*[] interfaces) {
        running_jobs++;
        scope (exit) {
            running_jobs--;
        }
        auto operational_feature = automation!operational;
        WalletInterface* receiver;
        WalletInterface* sender;
        pickWallets(interfaces, receiver, sender);
        assert(receiver != sender);

        operational_feature.SendNContractsFromwallet1Towallet2(sender, receiver, sendkernel);
        auto feat_group = operational_feature.run;
        run_counter++;
        if (feat_group.result.hasErrors) {
            writefln("operational test failed after %s runs", run_counter);
            return false;
        }
        return true;
    }

    bool job_failed;
    while (MonoTime.currTime <= end_clocktime || job_failed) {
        job_failed = !new_job(wallet_interfaces);
        Thread.sleep(1.seconds);
    }
    return 0;
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
    WalletInterface*[] wallets;
    bool sendkernel;
    bool send;

    TagionCurrency[] wallet_amounts;

    this(ref WalletInterface* sender, WalletInterface* receiver, bool sendkernel) {
        this.wallets ~= sender;
        this.wallets ~= receiver;
        this.sendkernel = sendkernel;
        this.send = !sendkernel;
    }

    @Given("i have a network")
    Document network() @trusted {
        writefln("sendkernel: %s, sendshell: %s", sendkernel, send);
        // dfmt off
        const wallet_switch = WalletInterface.Switch(
                update: true, 
                sendkernel: sendkernel,
                send: send);
        // dfmt on

        foreach (ref w; wallets[0 .. 2]) {
            check(w.secure_wallet.isLoggedin, "the wallet must be logged in!!!");
            w.operate(wallet_switch, []);
            wallet_amounts ~= w.secure_wallet.available_balance;
        }

        return result_ok;
    }

    Invoice invoice;
    TagionCurrency fees;
    @When("i send a valid contract from `wallet1` to `wallet2`")
    Document wallet2() @trusted {
        with (wallets[0].secure_wallet) {
            invoice = createInvoice("Invoice", 800.TGN);
            registerInvoice(invoice);
        }

        SignedContract signed_contract;

        with (wallets[1]) {
            check(secure_wallet.isLoggedin, "the wallet must be logged in!!!");
            auto result = secure_wallet.payment([invoice], signed_contract, fees);

            const message = secure_wallet.net.calcHash(signed_contract);
            const contract_net = secure_wallet.net.derive(message);
            const hirpc = HiRPC(contract_net);
            const hirpc_submit = hirpc.submit(signed_contract);

            if (sendkernel) {
                auto response = sendSubmitHiRPC(options.contract_address, hirpc_submit, contract_net);
                check(!response.isError, format("Error when sending kernel submit\n%s", response.toPretty));
            }
            else {
                auto response = sendShellSubmitHiRPC(options.addr ~ options.contract_shell_endpoint, hirpc_submit, contract_net);
                check(!response.isError, format("Error when sending shell submit\n%s", response.toPretty));
            }

            result.get;
        }

        return result_ok;
    }

    @When("the contract has been executed")
    Document executed() @trusted {
        Thread.sleep(20.seconds);
        return result_ok;
    }

    @Then("wallet1 and wallet2 balances should be updated")
    Document updated() @trusted {
        //dfmt off
        const wallet_switch = WalletInterface.Switch(
            trt_update : true,
            sendkernel: sendkernel,
            send: send);

        foreach (i, ref w; wallets[0 .. 2]) {
            writefln("Checking Wallet_%s", i);
            check(w.secure_wallet.isLoggedin, "the wallet must be logged in!!!");
            w.operate(wallet_switch, []);
            check(wallet_amounts[i] != w.secure_wallet.available_balance, "Wallet amount did not change");
        }

        with(wallets[0].secure_wallet) {
            auto expected = wallet_amounts[0] + invoice.amount;
            check(available_balance == expected, 
                    format("wallet 0 amount incorrect, expected %s got %s", expected, available_balance));
        }

        with(wallets[1].secure_wallet) {
            auto expected = wallet_amounts[1] - (invoice.amount + fees);
            check(available_balance == expected,
                    format("wallet 1 amount incorrect, expected %s got %s", expected, available_balance));
        }


        return result_ok;
    }

}
