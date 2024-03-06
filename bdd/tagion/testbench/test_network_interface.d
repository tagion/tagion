module tagion.testbench.test_network_interface;

import core.time;

import std.path;
import std.range;
import std.algorithm;
import std.format;
import std.file;

import tagion.wallet.SecureWallet;
import tagion.tools.shell.shelloptions;
import tagion.testbench.tools.Environment;
import tagion.services.options;
import tagion.wave.mode0;
import tagion.wave.common;

abstract class ITestNet {
    StdSecureWallet*[] my_wallets;

    const(Options)[] node_opts;

    bool hasShell;
    ShellOptions shell_opts;

    string dart_addr;
    string contract_addr;

    bool isAlive(Duration timeout);

    void start();
    void stop();

    invariant() {
        foreach(wallet; my_wallets) {
            assert(wallet.isLoggedin);
        }
    }
}

class Mode0TestNet : ITestNet {
    string data_dir;

    this(uint number_of_wallets, uint number_of_nodes, string full_module_name = __MODULE__) {
        const module_name = full_module_name.split(".")[$-1];
        this.data_dir = env.bdd_log.buildPath(module_name);
        this.hasShell = false;

        // Node Setup
        Options local_options = Options.defaultOptions;
        local_options.wave.number_of_nodes = number_of_nodes;
        local_options.wave.prefix_format = module_name ~ "_Node_%s_";
        local_options.subscription.address = contract_sock_addr(module_name ~ "SUBSCRIPTION");

        node_opts = getMode0Options(local_options, monitor: false);

        this.dart_addr = node_opts[0].dart_interface.sock_addr;
        this.contract_addr = node_opts[0].inputvalidator.sock_addr;

        foreach(i; 0..number_of_wallets) {
            StdSecureWallet* secure_wallet;
            secure_wallet = new StdSecureWallet(
                iota(0, 5)
                    .map!(n => format("%dquestion%d", i, n)).array,
                    iota(0, 5)
                    .map!(n => format("%danswer%d", i, n)).array,
                    4,
                    format("%04d", i),
            );
            this.my_wallets ~= secure_wallet;
        }
    }

    bool isAlive() => true;

    void create_files() {
        if (data_dir.exists) {
            rmdirRecurse(data_dir);
        }
        mkdirRecurse(data_dir);
    }
}
