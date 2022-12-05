module tagion.testbench.network.SSL_network_environment;
import std.process;
import tagion.testbench.tools.Environment;
import std.path;


immutable string sslserver;
immutable string sslclient;
immutable string cert;


shared static this() {
    sslserver = env.dbin.buildPath("sslserver");
    sslclient = env.dbin.buildPath("sslclient");
    cert = env.bdd.buildPath("ssl", "mycert.pem");
}
