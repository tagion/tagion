module tagion.tools.shell.shelloptions;
import tagion.utils.JSONCommon;
import tagion.services.options : contract_sock_addr;

enum mode0_prefix = "Node_1_";

@safe
struct ShellOptions {
    string tagion_sock_addr;

    void setDefault() nothrow {
        tagion_sock_addr = contract_sock_addr(mode0_prefix);
    }

    mixin JSONCommon;
    mixin JSONConfig;
}
