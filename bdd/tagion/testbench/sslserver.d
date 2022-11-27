module tagion.testbench.sslserver;

import std.stdio;

import tagion.behaviour.Behaviour;
import tagion.tools.Basic;

import tagion.testbench.network;
import tagion.network.SSLOptions;
import tagion.services.Options;
import tagion.testbench.tools.TestMain;
import tagion.testbench.Environment;
import tagion.testbench.network;

void setDefault(ref SSLOptions options, const Options opt) {
    options = opt.transaction.service;
}

mixin Main!_main;

int _main(string[] args) {
    auto setup = mainSetup!SSLOptions("sslserver", &setDefault);
    int result = testMain(setup, args);
    if (!result) {
        auto sslserver_feature = automation!SSL_server;
        sslserver_feature.CreatesASSLCertificate(setup.options);
        auto sslserver_context = sslserver_feature.run;
    }
    //    env.writeln;
    return result;
}
