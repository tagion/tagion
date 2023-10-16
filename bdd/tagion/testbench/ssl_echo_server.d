module tagion.testbench.ssl_echo_server;
import tagion.behaviour.Behaviour;
import tagion.testbench.network;
import tagion.tools.Basic;

import tagion.testbench.network.SSL_D_Client_test : DClientMultithreadingWithCServer;

import tagion.testbench.tools.Environment;

mixin Main!(_main);
int _main(string[] args) {
    if (env.stage == Stage.acceptance) {
        auto ssl_echo_feature = automation!(SSL_echo_test)();
        auto ssl_echo_context = ssl_echo_feature.run;
    }

    // auto ssl_echo_d_client_feature = automation!(SSL_D_Client_test)();
    // auto ssl_echo_d_client_context = ssl_echo_d_client_feature.run;

    // auto ssl_echo_d_server_feature = automation!(SSL_DC_Server_test)();
    // auto ssl_echo_d_server_context = ssl_echo_d_server_feature.run;

    // auto ssl_echo_c_multi_server_feature = automation!(SSL_C_server_C_client_multithread)();
    // auto ssl_echo_c_multi_server_context = ssl_echo_c_multi_server_feature.run;

    return 0;

}
