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
import tagion.basic.Types : FileExtension;
import tagion.basic.tagionexceptions;
import tagion.testbench.tools.Environment;
import tagion.tools.Basic : Main, __verbose_switch;
import tagion.tools.wallet.WalletInterface;
import tagion.tools.wallet.WalletOptions : WalletOptions;
import tagion.utils.JSONCommon;
import tagion.utils.StdTime;
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
    uint failed_runs;
    sdt_t start;
    sdt_t end;

    mixin HiBONRecord;
}

int _main(string[] args) {
    const program = args[0];
    string[] wallet_config_files;
    string[] wallet_pins;
    bool sendkernel = false;
    uint duration = 3;
    int max_failed_runs = 5;
    DurationUnit duration_unit = DurationUnit.days;

    // Enabled this for wallet_interface to print out debug info
    __verbose_switch = true;

    auto tx_stats = new TxStats;

    auto main_args = getopt(args,
            "w", "wallet config files", &wallet_config_files,
            "x", "wallet pins", &wallet_pins,
            "sendkernel", "Send requests directory to the kernel", &sendkernel,
            "duration", format("The duration the test should run for (current = %s)", duration), &duration,
            "unit", format("The duration unit on of %s (current = %s)", [EnumMembers!DurationUnit], duration_unit), &duration_unit,
            "max_failed_runs", format("The maximum amount of failed runs, before the process exits (current = %s)", max_failed_runs), &duration_unit,
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
    sdt_t start_sdt_time = currentTime();

    int run_counter;
    int failed_runs_counter;
    scope (exit) {
        const end_date = cast(DateTime)(Clock.currTime);
        writefln("Made %s runs", run_counter);
        writefln("Test ended on %s", end_date);
        tx_stats.transactions = run_counter - failed_runs_counter;
        tx_stats.failed_runs = failed_runs_counter;
        tx_stats.start = start_sdt_time;
        tx_stats.end = currentTime(); // sdt time

        const tx_file = buildPath(env.dlog, "tx_stats".setExtension(FileExtension.hibon));
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

        auto runs_file = File(buildPath(env.dlog, "runs.txt"), "w");
        runs_file.writeln(run_counter);
        runs_file.close;

        if (feat_group.result.hasErrors) {
            /// Never if max_failed_runs -1
            if (failed_runs_counter == max_failed_runs) {
                stop = true;
            }

            auto failed_run_file = buildPath(env.dlog, format("failed_%s", run_counter).setExtension(FileExtension
                    .hibon));
            fwrite(failed_run_file, *(feat_group.result));
            failed_runs_counter++;
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
    enum invoice_amount = 1000.TGN;
    WalletInterface* sender;
    WalletInterface* receiver;
    bool sendkernel;
    bool send;

    TagionCurrency receiver_amount;
    TagionCurrency sender_amount;
    TxStats* tx_stats;

    this(ref WalletInterface* sender, WalletInterface* receiver, bool sendkernel, TxStats* tx_stats) {
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
                sendkernel: sendkernel,
                send: send);
        // dfmt on

        with (receiver) {
            check(secure_wallet.isLoggedin, "the wallet must be logged in!!!");
            operate(wallet_switch, []);
            receiver_amount = secure_wallet.available_balance;
        }

        with (sender) {
            check(secure_wallet.isLoggedin, "the wallet must be logged in!!!");
            operate(wallet_switch, []);
            sender_amount = secure_wallet.available_balance;
        }

        return result_ok;
    }

    Invoice invoice;
    TagionCurrency fees;
    @When("i send a valid contract from `wallet1` to `wallet2`")
    Document wallet2() @trusted {
        with (receiver.secure_wallet) {
            invoice = createInvoice("Invoice", invoice_amount);
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
            secure_wallet.account.hirpcs ~= hirpc_submit.toDoc;

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
        version(TRT_READ_REQ) {
        const wallet_switch = WalletInterface.Switch(
            trt_read: true, 
            sendkernel: sendkernel,
            send: send);
        }
        else {
        const wallet_switch = WalletInterface.Switch(
            trt_update : true,
            sendkernel: sendkernel,
            send: send);
        }

        enum update_retries = 20;
        enum retry_delay = 5.seconds;

        void check_balance(WalletInterface* wallet, const TagionCurrency expected) {
            with(wallet) {
                check(secure_wallet.isLoggedin, "the wallet must be logged in!!!");
                foreach(i; 0 .. update_retries) {
                    writefln("wallet try update %s of %s", i+1, update_retries);
                    try {
                        operate(wallet_switch, []);
                    }
                    catch(TagionException e) {
                        writeln(e);
                    }
                    if(secure_wallet.available_balance == expected) {
                        return;
                    }
                    Thread.sleep(retry_delay);
                }
                check(secure_wallet.available_balance == expected, 
                        format("wallet amount incorrect, expected %s got %s",
                        expected, secure_wallet.available_balance));
            }
        }

        check_balance(receiver, (receiver_amount + invoice.amount));
        check_balance(sender, (sender_amount - (invoice.amount + fees)));

        tx_stats.total_fees += fees;
        tx_stats.total_sent += invoice.amount;


        return result_ok;
    }

}
