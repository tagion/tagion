module tagion.tools.shell.shelloptions;
import tagion.utils.JSONCommon;
import tagion.services.options : contract_sock_addr;

enum mode0_prefix = "Node_1_";

@safe
struct ShellOptions {
    string tagion_sock_addr;
    string tagion_dart_sock_addr;
    string contract_endpoint;
    string tagion_subscription;

    void setDefault() nothrow {
        tagion_sock_addr = contract_sock_addr(mode0_prefix~"CONTRACT_");
        tagion_dart_sock_addr = contract_sock_addr(mode0_prefix~"DART_");
        tagion_subscription = contract_sock_addr("SUBSCRIPTION_");
        contract_endpoint = "http://localhost:8088";
    }

    mixin JSONCommon;
    mixin JSONConfig;
}
