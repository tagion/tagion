module tagion.tools.shell.shelloptions;
import tagion.utils.JSONCommon;
import tagion.services.options : contract_sock_addr;

enum mode0_prefix = "Node_1_CONTRACT_";

@safe
struct ShellOptions {
    string tagion_sock_addr;
    string contract_endpoint;

    void setDefault() nothrow {
        tagion_sock_addr = contract_sock_addr(mode0_prefix);
        contract_endpoint = "http://localhost:8088";
    }

    mixin JSONCommon;
    mixin JSONConfig;
}
