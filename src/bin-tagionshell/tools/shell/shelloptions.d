module tagion.tools.shell.shelloptions;

@safe:

import tagion.services.options : contract_sock_addr;
import tagion.utils.JSONCommon;
import std.format;

enum mode0_prefix = "Node_%d_";

import std.exception;

struct ShellOptions {
    string shell_uri;
    string shell_api_prefix;
    string contract_endpoint;
    string dart_endpoint;
    string dartcache_endpoint;
    string tagion_subscription_addr;
    string bullseye_endpoint;
    string i2p_endpoint;
    string sysinfo_endpoint;
    string selftest_endpoint;
    string default_i2p_wallet;
    string default_i2p_wallet_pin;
    uint number_of_nodes;
    string contract_addr_prefix;
    string dart_addr_prefix;

    void setDefault() nothrow {
        contract_addr_prefix = "CONTRACT_";
        dart_addr_prefix = "DART_";
        shell_uri = "http://0.0.0.0:8080";
        tagion_subscription_addr = contract_sock_addr("SUBSCRIPTION_");
        shell_api_prefix = "/api/v1";
        contract_endpoint = "/contract";
        dart_endpoint = "/dart";
        dartcache_endpoint = "/dartcache";
        bullseye_endpoint = "/bullseye";
        i2p_endpoint = "/invoice2pay";
        sysinfo_endpoint = "/sysinfo";
        selftest_endpoint = "/selftest";
        default_i2p_wallet = "./wallets/wallet1.json";
        default_i2p_wallet_pin = "0001";
        number_of_nodes = 5;
    }

    /// Gives a new node address each time it is called
    string node_contract_addr() nothrow {
        uint node_number = contract_robin.next(number_of_nodes);
        return contract_sock_addr(assumeWontThrow(format(mode0_prefix, node_number)) ~ contract_addr_prefix);
    }

    /// Gives a new node address each time it is called
    string node_dart_addr() nothrow {
        uint node_number = dart_robin.next(number_of_nodes);
        return contract_sock_addr(assumeWontThrow(format(mode0_prefix, node_number)) ~ dart_addr_prefix);
    }

    mixin JSONCommon;
    mixin JSONConfig;
}

final synchronized class RoundRobin {
    import core.atomic;

    protected uint counter;
    uint next(const uint number_of_nodes) nothrow {
        if ((counter.atomicLoad + 1) >= number_of_nodes) {
            counter.atomicStore(0);
        }
        else {
            counter.atomicOp!"+="(1);
        }
        return counter;
    }
}

shared RoundRobin contract_robin;
shared RoundRobin dart_robin;
shared static this() {
    contract_robin = new RoundRobin();
    dart_robin = new RoundRobin();
}
