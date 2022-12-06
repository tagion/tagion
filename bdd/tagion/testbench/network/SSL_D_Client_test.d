module tagion.testbench.network.SSL_D_Client_test;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.network.SSLSocketTest;
import tagion.testbench.tools.Environment;
import tagion.testbench.network.SSL_network_environment : sslclient, sslserver, cert;

import std.stdio;
import std.string;
import std.process;
import std.conv;

enum feature = Feature("simple D client", ["This is a test with the C server and a simple D client."]);

alias FeatureContext = Tuple!(DClientWithCServer, "DClientWithCServer", FeatureGroup*, "result");

@safe @Scenario("D Client with C server", [])
class DClientWithCServer {
    ushort port = 8003;

    @Given("I have a simple sslserver.")
    Document _sslserver() @trusted {
        immutable sslserver_start_command = [
            sslserver,
            port.to!string,
            cert,
        ];
        writefln("%s", sslserver_start_command.join(" "));

        auto ssl_server = spawnProcess(sslserver_start_command);
        // server_pipe_id = ssl_server.pid;
        return result_ok;
    }

    @Given("I have a simple D sslclient.")
    Document _sslclient() {
        const response = echoSSLSocket("localhost", port, "wowo").strip();
        writefln("response:<%s>", response);
        check(response == "wowo", "Error response not found");
        const response_1 = echoSSLSocket("localhost", port, "wowo1").strip();
        writefln("response:<%s>", response_1);
        check(response_1 == "wowo1", "Error response not found1");
         return result_ok;
    }

    @When("I send many requests repeadtly.")
    Document repeadtly() {
        return Document();
    }

    @Then("the sslserver should not chrash.")
    Document chrash() {
        return Document();
    }

}
