module tagion.testbench.network.SSL_network_environment;
import std.process;
import tagion.testbench.tools.Environment;
import std.path;


immutable string sslserver;
immutable string sslclient;
immutable string cert;


shared static this() {
    sslserver = env.dbin.buildPath("ssl_server");
    sslclient = env.dbin.buildPath("ssl_client");
    cert = env.bdd.buildPath("extras", "ssl", "mycert.pem");
}
