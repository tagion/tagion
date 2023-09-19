module tagion.tools.shell.shelloptions;
import tagion.utils.JSONCommon;

@safe
struct ShellOptions {
    int wowo;




    void setDefault() pure nothrow {
        wowo = 10;
    }
    mixin JSONCommon;
    mixin JSONConfig;

}
