module tagion.testbench.network.SSL_DC_Server_test;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.network.SSL_network_environment : client_send, sslserver, sslclient, cert;
import tagion.testbench.network.SSLSocketTest;

import std.stdio;
import std.string;
import std.process;
import std.conv;
import core.thread;
import core.time;
import std.concurrency;

enum feature = Feature("simple DC server", [
            "This is a test with the DC server and a simple c client."
        ]);

alias FeatureContext = Tuple!(CClientWithDCServer, "CClientWithDCServer", FeatureGroup*, "result");

@safe @Scenario("C Client with D server", [])
class CClientWithDCServer
{
    ushort port = 8003;
    int calls = 1000;

    @Given("I have a simple sslserver in D.") 
    Document d() @trusted
    {
        auto server = spawn(&_SSLSocketServer, "localhost", port, cert);
        Thread.sleep(100.msecs);
        return result_ok;
    }

    @Given("I have a simple c sslclient.")
    Document _sslclient()
    {
        const response = client_send("wowo", port).strip();
        check(response == "wowo", "Message not received");
        return result_ok;
    }

    @When("I send many requests repeadtly.")
    Document repeadtly()
    {
        for (int i = 0; i < calls; i++)
        {
            string message = format("test%s", i);
            const response = client_send(message, port).strip();
            writefln(response);
            check(message == response, format("Error response not found got: <%s>", response));
        }
        return result_ok;
    }

    @Then("the sslserver should not chrash.")
    Document chrash()
    {
        const response = client_send("EOC", port);
        return result_ok;
    }

}
