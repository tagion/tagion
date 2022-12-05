module tagion.testbench.ssl_echo_server;
import tagion.behaviour.Behaviour;
import tagion.testbench.network;
import tagion.tools.Basic;

import tagion.hibon.HiBONRecord : fwrite;


mixin Main!(_main);
int _main(string[] args)
{
    auto ssl_echo_feature = automation!(SSL_echo_test)();
    auto ssl_echo_context = ssl_echo_feature.run;

    return 0;

}
