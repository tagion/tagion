module tagion.testbench.network.SSL_network_environment;
import std.process;
import tagion.testbench.tools.Environment;
import std.path;
import tagion.behaviour;

import std.process;
import std.conv;
import std.string;
import std.stdio;
import std.concurrency;

immutable string sslserver;
immutable string ssltestserver;
immutable string sslclient;
immutable string cert;

shared static this() {
    sslserver = env.dbin.buildPath("ssl_c_server");
    ssltestserver = env.dbin.buildPath("ssl_c_test_server");
    sslclient = env.dbin.buildPath("ssl_c_client");
    cert = env.bdd.buildPath("extras", "ssl", "mycert.pem");
}

string client_send(string message, ushort port) @trusted {
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

@trusted
void client_send_task(ushort port, string prefix, uint calls) {
    foreach (i; 0 .. calls) {
        const message = format("%s%s", prefix, i);
        const response = client_send(message, port);
        writefln("response: <%s>", response);
        check(response == message, format("Error: message and response not the same got: <%s>", response));

    }
    ownerTid.send(true);
}
