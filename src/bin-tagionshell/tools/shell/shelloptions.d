module tagion.tools.shell.shelloptions;
import tagion.utils.JSONCommon;
import tagion.services.options : contract_sock_addr;

enum mode0_prefix = "Node_1_";

@safe
struct ShellOptions {
    string shell_uri;
    string shell_api_prefix;
    string contract_endpoint;
    string dart_endpoint;
    string tagion_sock_addr;
    string tagion_dart_sock_addr;
    string tagion_subscription;
    string i2p_endpoint;
    string default_i2p_wallet;
    string default_i2p_wallet_pin;

    void setDefault() nothrow {
        tagion_sock_addr = contract_sock_addr(mode0_prefix~"CONTRACT_");
        tagion_dart_sock_addr = contract_sock_addr(mode0_prefix~"DART_");
        tagion_subscription = contract_sock_addr("SUBSCRIPTION_");
        shell_uri = "http://localhost:8088";
        shell_api_prefix = "/api/v1";
        contract_endpoint = "/contract";
        dart_endpoint = "/dart";
        i2p_endpoint = "/invoice2pay";
        default_i2p_wallet = "./wallets/wallet1";
        default_i2p_wallet_pin = "0001";
    }

    mixin JSONCommon;
    mixin JSONConfig;
}
