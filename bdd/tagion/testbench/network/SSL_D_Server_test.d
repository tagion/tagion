module tagion.testbench.network.SSL_D_Server_test;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.network.SSL_network_environment : sslclient, sslserver, cert;
import tagion.testbench.network.SSLSocketTest;

import std.stdio;
import std.string;
import std.process;
import std.conv;
import core.thread;
import core.time;
import std.concurrency;

enum feature = Feature("simple D server", [
            "This is a test with the D server and a simple c client."
        ]);

alias FeatureContext = Tuple!(
	CClientWithDServer, "CClientWithDServer", 
	FeatureGroup*, "result");

@safe @Scenario("C Client with D server", [])
class CClientWithDServer
{
    ushort port = 8003;
    int calls = 1000;
    @Given("I have a simple sslserver in D.")
    Document d() @trusted
    {
        auto server = spawn(&echoSSLSocketServer, "localhost", port, cert);
        Thread.sleep(1.msecs);
        return result_ok;
    }

    @Given("I have a simple c sslclient.")
    Document _sslclient()
    {
        return Document();
    }

    @When("I send many requests repeadtly.")
    Document repeadtly()
    {
        return Document();
    }

    @Then("the sslserver should not chrash.")
    Document chrash()
    {
        return Document();
    }

}
