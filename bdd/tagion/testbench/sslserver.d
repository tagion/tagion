module tagion.testbench.sslserver;

import std.stdio;
import std.typecons;

import tagion.behaviour.Behaviour;
import tagion.tools.Basic;
import tagion.hibon.HiBONRecord : fwrite;

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
    if (result == 0) {
        auto sslserver_handle = automation!SSL_server;
        pragma(msg, typeof(sslserver_handle));
        pragma(msg, "CreateASSLCertificate", typeof(sslserver_handle.opDispatch!"CreatesASSLCertificate"));
//        alias Create = sslserver_handle.opDispatch!"CreatesASSLCertificate";
        //sslserver_handle.opDispatch!"CreatesASSLCertificate"(setup.options.openssl);
        sslserver_handle.CreatesASSLCertificate(setup.options.openssl);
        auto sslserver_context=sslserver_handle.run;
    "/tmp/result.hibon".fwrite(*sslserver_context.result);
       // pragma(msg, sslserver_handle.CreatesASSLCertificate);
        //    sslserber_handle.CreatesASSLCertificate(setup.options);
    }
    //    env.writeln;
    return result;
}
