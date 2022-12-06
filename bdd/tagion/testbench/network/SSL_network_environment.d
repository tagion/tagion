module tagion.testbench.network.SSL_network_environment;
import std.process;
import tagion.testbench.tools.Environment;
import std.path;

import std.process;
import std.conv;
import std.string;
import std.stdio;

immutable string sslserver;
immutable string sslclient;
immutable string cert;

shared static this()
{
    sslserver = env.dbin.buildPath("ssl_server");
    sslclient = env.dbin.buildPath("ssl_client");
    cert = env.bdd.buildPath("extras", "ssl", "mycert.pem");
}

string client_send(string message, ushort port) @trusted
{
    immutable sslclient_send_command = [
        sslclient,
        "localhost",
        port.to!string,
    ];
    // writefln("%s", sslclient_send_command.join(" "));

    auto sslclient_send = pipeProcess(sslclient_send_command);
    sslclient_send.stdin.writeln(message);
    sslclient_send.stdin.flush();
    //sslclient_send.stdin.close();

    wait(sslclient_send.pid);
    // Thread.sleep( 50.msecs );
    const stdout_message = sslclient_send.stdout.readln().strip();

    //sslclient_send.stdout.close();
    //sslclient_send.stderr.close();
    return stdout_message;
}
