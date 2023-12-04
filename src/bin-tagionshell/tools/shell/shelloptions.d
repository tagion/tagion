module tagion.tools.shell.shelloptions;
import tagion.services.options : contract_sock_addr;
import tagion.utils.JSONCommon;
import std.format;

enum mode0_prefix = "Node_%d_";

import std.exception;

shared static size_t counter = 0;


@safe
struct ShellOptions {
    string shell_uri;
    string shell_api_prefix;
    string contract_endpoint;
    string dart_endpoint;
    string dartcache_endpoint;
    string tagion_sock_addr;
    string tagion_dart_sock_addr;
    string tagion_subscription;
    string i2p_endpoint;
    string default_i2p_wallet;
    string default_i2p_wallet_pin;
    size_t number_of_nodes;

    void setDefault() nothrow {
        tagion_sock_addr = contract_sock_addr(assumeWontThrow(format(mode0_prefix, 1))~"CONTRACT_");
        tagion_dart_sock_addr = contract_sock_addr(mode0_prefix~"DART_");
        tagion_subscription = contract_sock_addr("SUBSCRIPTION_");
        shell_uri = "http://0.0.0.0:8080";
        shell_api_prefix = "/api/v1";
        contract_endpoint = "/contract";
        dart_endpoint = "/dart";
        dartcache_endpoint = "/dartcache";
        i2p_endpoint = "/invoice2pay";
        default_i2p_wallet = "./wallets/wallet1.json";
        default_i2p_wallet_pin = "0001";
        number_of_nodes = 5;
    }



    string getRndDARTAddress() nothrow {
        import core.atomic;

        size_t loaded_count = counter.atomicLoad();
        if (loaded_count == number_of_nodes-1) {
            counter.atomicOp!"-="(4);
        } else {
            counter.atomicOp!"+="(1);
        }
        
        try {
            return contract_sock_addr(format(mode0_prefix, loaded_count)~"DART_");
        } catch(Exception e) {
            assert(false);
        }
    }

    mixin JSONCommon;
    mixin JSONConfig;
}
