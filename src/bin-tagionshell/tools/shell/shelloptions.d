module tagion.tools.shell.shelloptions;

@safe:

import tagion.services.options : contract_sock_addr;
import tagion.utils.JSONCommon;
import std.format;

enum mode0_prefix = "Node_%d_";

import std.exception;

struct ShellOptions {
    string contract_addr_prefix = "CONTRACT_";
    string dart_addr_prefix = "DART_";
    string shell_uri = "http://0.0.0.0:8080";
    string recorder_subscription_tag = "recorder";
    string dart_subscription_task_prefix = "Node_0_";
    string trt_subscription_tag = "trt_created";
    string shell_api_prefix = "/api/v1";
    string contract_endpoint = "/contract";
    string hirpc_endpoint = "/hirpc";
    string dart_endpoint = "/dart";
    string trt_endpoint = "/trt";
    string bullseye_endpoint = "/bullseye";
    string i2p_endpoint = "/invoice2pay";
    string sysinfo_endpoint = "/sysinfo";
    string selftest_endpoint = "/selftest";
    string version_endpoint = "/version";
    string default_i2p_wallet = "./wallets/wallet1.json";
    string default_i2p_wallet_pin = "0001";
    uint number_of_nodes = 5;
    uint sock_recvtimeout = 10000;
    uint sock_recvdelay = 10;
    uint sock_connectretry = 32;
    uint dartcache_size = 4096;
    double dartcache_ttl_msec = 30.0;
    string mode0_prefix = "Node_%d_";
    bool cache_enabled = false; // if to use caches
    bool process_hirpc = true; // if false - pass all hirpc requests through as is

    bool save_rpcs_enable = true; // Whether or not the shell should save incoming contracts
    string save_rpcs_task = "rpcs_saver"; // Task name of the worker thread which saves the rpc contracts

    string tagion_subscription_addr;
    string ws_pub_uri;

    void setDefault() nothrow {
        tagion_subscription_addr = contract_sock_addr("SUBSCRIPTION_");
        version(TAGIONSHELL_WEB_SOCKET) {
            ws_pub_uri = "ws://0.0.0.0:8080/api/v1/subscribe";
        }
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

    static ShellOptions defaultOptions() nothrow {
        ShellOptions opts;
        opts.setDefault;
        return opts;
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
