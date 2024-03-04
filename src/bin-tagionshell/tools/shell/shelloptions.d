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
    string shell_api_prefix_v2;
    string contract_endpoint;
    string hirpc_endpoint;
    string dart_endpoint;
    string trt_endpoint;
    string tagion_subscription_addr;
    string recorder_subscription_tag;
    string dart_subscription_task_prefix;
    string trt_subscription_tag;
    string bullseye_endpoint;
    string i2p_endpoint;
    string sysinfo_endpoint;
    string selftest_endpoint;
    string version_endpoint;
    string default_i2p_wallet;
    string default_i2p_wallet_pin;
    uint number_of_nodes;
    string contract_addr_prefix;
    string dart_addr_prefix;
    uint sock_recvtimeout;
    uint sock_recvdelay;
    uint sock_connectretry;
    uint dartcache_size;
    double dartcache_ttl_msec;
    string mode0_prefix;
    bool cache_enabled;    // wether to use caches
    bool process_hirpc;    // if false - pass all hirpc requests through as is
    string ws_pub_uri;

    bool save_rpcs_enable = true; // Whether or not the shell should save incoming contracts
    string save_rpcs_task = "rpcs_saver"; // Task name of the worker thread which saves the rpc contracts

    void setDefault() nothrow {
        contract_addr_prefix = "CONTRACT_";
        dart_addr_prefix = "DART_";
        shell_uri = "http://0.0.0.0:8080";
        tagion_subscription_addr = contract_sock_addr("SUBSCRIPTION_");
        recorder_subscription_tag = "recorder";
        dart_subscription_task_prefix = "Node_0_";
        trt_subscription_tag = "trt_created";
        shell_api_prefix = "/api/v1";
        shell_api_prefix_v2 = "/api/v2";
        contract_endpoint = "/contract";
        hirpc_endpoint = "/hirpc";
        dart_endpoint = "/dart";
        trt_endpoint = "/trt";
        bullseye_endpoint = "/bullseye";
        i2p_endpoint = "/invoice2pay";
        sysinfo_endpoint = "/sysinfo";
        selftest_endpoint = "/selftest";
        version_endpoint = "/version";
        default_i2p_wallet = "./wallets/wallet1.json";
        default_i2p_wallet_pin = "0001";
        number_of_nodes = 5;
        sock_recvtimeout = 10000;
        sock_recvdelay = 10;
        sock_connectretry = 32;
        dartcache_size = 4096;
        dartcache_ttl_msec = 30.0;
        mode0_prefix = "Node_%d_";
        cache_enabled = false;
        process_hirpc = true;
        ws_pub_uri = "";
        version(TAGIONSHELL_WEB_SOCKET) {
            ws_pub_uri = "ws://0.0.0.0:6969";
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
