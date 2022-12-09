module tagion.testbench.network.SSL_C_server_C_client_multithread;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.network.SSLSocketTest;
import tagion.testbench.tools.Environment;
import tagion.testbench.network.SSL_network_environment : client_send_task, client_send, sslclient, sslserver, ssltestserver, cert;

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
    uint number_of_clients = 100;
    string host = "localhost";
    int calls = 100;

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
    Document sslclient() @trusted
    {
        const response = client_send("wowo", port).strip();
        check(response == "wowo", "Message not received");
        return result_ok;
    }

    @When("I send many requests with multithread.")
    Document multithread() @trusted
    {
        foreach(i; 0 .. number_of_clients) {
            spawn(&client_send_task, port, format("%stest", i), calls);
        }

        foreach(i; 0.. number_of_clients) {
            writefln("WAITING for receive %s", i);
            writefln("receive%s, %s", i, receiveOnly!bool);
        }

        return result_ok;
    }

    @Then("the sslserver should not chrash.")
    Document chrash() @trusted
    {
        const response = client_send("EOC", port);
        return result_ok;
    }

}
