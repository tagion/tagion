import tagion.testbench.e2e.network;

import std.string;
import std.process;

struct NetworkOptions {
    string[] shell_addresses;
    string[] node_dart_addresses;
    string[] node_input_addresses;
    string[] node_subscription_addresses;

    void parseFromEnv() {
        shell_addresses = environment.get("SHELL_ADDRESSES").split(" ");
        node_dart_addresses = environment.get("NODE_DART_ADDRESSES").split(" ");
        node_input_addresses = environment.get("NODE_INPUT_ADDRESSES").split(" ");
        node_subscription_addresses = environment.get("NODE_SUBSCRIPTION_ADDRESSES").split(" ");
    }
}
