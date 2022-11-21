module tagion.testbench.sslserver;

import std.stdio;
import std.typecons;
import std.path;
import core.time;

import tagion.behaviour.Behaviour;
import tagion.tools.Basic;
import tagion.hibon.HiBONRecord : fwrite;

import tagion.network.SSLOptions;
import tagion.services.Options;
import tagion.testbench.tools.TestMain;
import tagion.testbench.Environment;
import tagion.testbench.tools.TimeOut;

import tagion.testbench.network;

void setDefault(ref SSLOptions options, const Options opt) {
    options = opt.transaction.service;
    options.openssl.certificate = buildPath(env.bdd_log, options.openssl.certificate);
    options.openssl.private_key = buildPath(env.bdd_log, options.openssl.private_key);
}

mixin Main!_main;

int _main(string[] args) {
    timeout(1.seconds);
    writefln("args=%s", args);
    auto setup = mainSetup!SSLOptions("sslserver", &setDefault);
    int result = testMain(setup, args);
    if (result == 0) {
        writefln("sslserver=%s", setup.options.openssl);
        auto sslserver_handle = automation!SSL_server;
        sslserver_handle.CreatesASSLCertificate(setup.options.openssl);
        sslserver_handle.SSLServiceUsingASpecifiedCertificate(setup.options, "ssl_test_task");
        auto sslserver_context = sslserver_handle.run;
        "/tmp/result.hibon".fwrite(*sslserver_context.result);
    }
    return result;
}
