module tagion.testbench.e2e.operational;
// Default import list for bdd
import core.thread;
import core.time;
import std.algorithm;
import std.file;
import std.traits;
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
import tagion.hibon.HiBONFile;
import tagion.script.TagionCurrency;
import tagion.script.common;
import tagion.testbench.tools.Environment;
import tagion.tools.Basic : Main, __verbose_switch;
import tagion.tools.wallet.WalletInterface;
import tagion.tools.wallet.WalletOptions : WalletOptions;
import tagion.utils.JSONCommon;
import tagion.wallet.AccountDetails;

alias operational = tagion.testbench.e2e.operational;

mixin Main!(_main);

enum DurationUnit {
    minutes,
    hours,
    days,
}

WalletInterface* createInterface(string config, string pin) {
    WalletOptions opts;
    opts.load(config);
    auto wallet_interface = new WalletInterface(opts);
    check(wallet_interface.load, "Wallet %s could not be loaded".format(config));
    check(wallet_interface.secure_wallet.login(pin), "Wallet %s %s, not logged in".format(config, pin));
    writefln("Wallet logged in %s", wallet_interface.secure_wallet.isLoggedin);
    return wallet_interface;
}

@recordType("tx_stats")
struct TxStats {
    TagionCurrency total_fees;
    TagionCurrency total_sent;
    uint transactions;

    mixin HiBONRecord;
}

int _main(string[] args) {
    const program = args[0];
    string[] wallet_config_files;
    string[] wallet_pins;
    bool sendkernel = false;
    int duration = 3;
    DurationUnit duration_unit = DurationUnit.days;

    __verbose_switch = true;

    auto tx_stats = new TxStats;

    auto main_args = getopt(args,
            "w", "wallet config files", &wallet_config_files,
            "x", "wallet pins", &wallet_pins,
            "sendkernel", "Send requests directory to the kernel", &sendkernel,
            "duration", format("The duration the test should run for (current = %s)", duration), &duration,
            "unit", format("The duration unit on of %s (current = %s)", [EnumMembers!DurationUnit], duration_unit), &duration_unit,
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

    if (!wallet_config_files.length == 2) {
        writeln("Exactly 2 wallets should be provided");
        return 1;
    }

    if (wallet_pins.empty) {
        foreach (i, _; wallet_config_files) {
            wallet_pins ~= format("%04d", i + 1);
        }
    }

    check(wallet_pins.length == wallet_config_files.length, "wallet configs and wallet pins were not the same amount");

    alias ConfigAndPin = Tuple!(string, "config", string, "pin");
    ConfigAndPin[] configs_and_pins
        = wallet_config_files.zip(wallet_pins).map!(c => ConfigAndPin(c[0], c[1])).array;

    Duration max_runtime;
    with (DurationUnit) final switch (duration_unit) {
    case days:
        max_runtime = duration.days;
        break;
    case hours:
        max_runtime = duration.hours;
        break;
    case minutes:
        max_runtime = duration.minutes;
        break;
    }

    void pickWallets(ref ConfigAndPin[] configs_and_pins, out ConfigAndPin sender, out ConfigAndPin receiver, uint run)
    in (configs_and_pins.length >= 2)
    out (; sender != receiver)
    do {
        sender = configs_and_pins[!(run & 1)];
        receiver = configs_and_pins[(run & 1)];
    }

    // Times of the monotomic clock
    const start_clocktime = MonoTime.currTime;
    const end_clocktime = start_clocktime + max_runtime;

    // Date for pretty reporting
    const start_date = cast(DateTime) Clock.currTime;
    const predicted_end_date = start_date + max_runtime;

    int run_counter;
    scope (exit) {
        const end_date = cast(DateTime)(Clock.currTime);
        writefln("Made %s runs", run_counter);
        writefln("Test ended on %s", end_date);
        const tx_file = buildPath(env.dlog, "tx_stats.hibon");
        mkdirRecurse(dirName(tx_file));
        fwrite(tx_file, *tx_stats);
    }

    writefln("Starting operational test now on\n\t%s\nand will end in %s, on\n\t%s",
            start_date, max_runtime,
            predicted_end_date);

    bool stop;
    while (!stop) {
        scope (failure) {
            stop = true;
        }
        run_counter++;

        ConfigAndPin sender;
        ConfigAndPin receiver;
        pickWallets(configs_and_pins, sender, receiver, run_counter);

        auto sender_interface = createInterface(sender.config, sender.pin);
        auto receiver_interface = createInterface(receiver.config, receiver.pin);

        writefln("Making transaction between sender %s and receiver %s", sender.config, receiver.config);

        auto operational_feature = automation!operational;
        operational_feature.SendNContractsFromwallet1Towallet2(sender_interface, receiver_interface, sendkernel, tx_stats);
        auto feat_group = operational_feature.run;

        auto run_file = File(buildPath(env.dlog, "runs.txt"), "w");
        run_file.writeln(run_counter);
        run_file.close;

        if (feat_group.result.hasErrors) {
            stop = true;
            return 1;
        }

        stop = (MonoTime.currTime >= end_clocktime);
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
    WalletInterface* sender;
    WalletInterface* receiver;
    bool sendkernel;
    bool send;

    TagionCurrency[] wallet_amounts;
    TxStats* tx_stats;

    this(ref WalletInterface* sender, WalletInterface* receiver, bool sendkernel, TxStats* tx_stats) {
        this.wallets ~= sender;
        this.wallets ~= receiver;
        this.sender = sender;
        this.receiver = receiver;
        this.sendkernel = sendkernel;
        this.send = !sendkernel;
        this.tx_stats = tx_stats;
    }

    @Given("i have a network")
    Document network() @trusted {
        writefln("sendkernel: %s, sendshell: %s", sendkernel, send);
        // dfmt off
        const wallet_switch = WalletInterface.Switch(
                update: true, 
                sum: true,
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
        with (receiver.secure_wallet) {
            invoice = createInvoice("Invoice", 800.TGN);
            registerInvoice(invoice);
        }

        SignedContract signed_contract;

        with (sender) {
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
        Thread.sleep(25.seconds);
        return result_ok;
    }

    @Then("wallet1 and wallet2 balances should be updated")
    Document updated() @trusted {
        //dfmt off
        const wallet_switch = WalletInterface.Switch(
            trt_update : true,
            sum: true,
            sendkernel: sendkernel,
            send: send);

        foreach (i, ref w; wallets[0 .. 2]) {
            writefln("Checking Wallet_%s", i);
            check(w.secure_wallet.isLoggedin, "the wallet must be logged in!!!");
            w.operate(wallet_switch, []);
            check(wallet_amounts[i] != w.secure_wallet.available_balance, "Wallet amount did not change");
        }

        with(receiver.secure_wallet) {
            auto expected = wallet_amounts[0] + invoice.amount;
            check(available_balance == expected, 
                    format("wallet 0 amount incorrect, expected %s got %s", expected, available_balance));
        }

        with(sender.secure_wallet) {
            auto expected = wallet_amounts[1] - (invoice.amount + fees);
            check(available_balance == expected,
                    format("wallet 1 amount incorrect, expected %s got %s", expected, available_balance));
        }

        tx_stats.total_fees += fees;
        tx_stats.total_sent += invoice.amount;


        return result_ok;
    }

}
