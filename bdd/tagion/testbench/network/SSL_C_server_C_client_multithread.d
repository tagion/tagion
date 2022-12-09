module tagion.testbench.network.SSL_C_server_C_client_multithread;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.network.SSLSocketTest;
import tagion.testbench.tools.Environment;
import tagion.testbench.network.SSL_network_environment : client_send, sslclient, sslserver, ssltestserver, cert;

import std.stdio;
import std.string;
import std.process;
import std.conv;
import core.thread;
import core.time;
import std.concurrency;

enum feature = Feature("C client and C multithread server", [
            "This is a test for multithread C server"
        ]);

alias FeatureContext = Tuple!(CClientWithCMultithreadserver, "CClientWithCMultithreadserver", FeatureGroup*, "result");

@safe @Scenario("C Client with C multithread_server", [])
class CClientWithCMultithreadserver
{
    ushort port = 8003;
    string host = "localhost";
    int calls = 1000;

    @Given("I have a sslserver in C.")
    Document c() @trusted
    {
        immutable sslserver_start_command = [
            ssltestserver,
            host,
            port.to!string,
            cert,
        ];
        auto ssl_server = spawnProcess(sslserver_start_command);
        Thread.sleep(100.msecs);

        return result_ok;
    }

    @Given("I have a simple c _sslclient.")
    Document sslclient()
    {
        const response = client_send("wowo", port).strip();
        check(response == "wowo", "Message not received");
        return result_ok;
    }

    @When("I send many requests with multithread.")
    Document multithread()
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
