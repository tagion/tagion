module tagion.testbench.ssl_server;

import std.stdio;
import std.typecons;
import std.path;
import core.time;

import tagion.behaviour.Behaviour;
import tagion.tools.Basic;

import tagion.network.SSLServiceOptions;
import tagion.services.Options;
import tagion.testbench.tools.TestMain;
import tagion.testbench.tools.Environment;

import tagion.testbench.network;

void setDefault(ref SSLServiceOptions options, const Options opt) {
    options = opt.transaction.service;
    writefln("options.cert.certificate=%s", options.cert.certificate);
    options.cert.certificate = buildPath(env.bdd_log, options.cert.certificate);
    options.cert.private_key = buildPath(env.bdd_log, options.cert.private_key);
}

mixin Main!_main;

int _main(string[] args) {
    //    timeout(1.seconds);
    auto setup = mainSetup!SSLServiceOptions("ssl_server", &setDefault);
    int result = testMain(setup, args);

    //	auto 
    if (result == 0) {

        writefln("sslserver=%s", setup.options.cert);
        auto sslserver_handle = automation!SSL_server;
        sslserver_handle.CreatesASSLCertificate(setup.options.cert);
        sslserver_handle.SSLServiceUsingASpecifiedCertificate(setup.options, "ssl_test_task");
        auto sslserver_context = sslserver_handle.run;
    }
    return result;
}
