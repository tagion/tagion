module tagion.testbench.network.SSL_D_Client_test;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.network.SSLSocketTest;
import tagion.testbench.tools.Environment;
import tagion.testbench.network.SSL_network_environment : sslclient, sslserver, ssltestserver, cert;

import std.stdio;
import std.string;
import std.process;
import std.conv;
import core.thread;
import core.time;
import std.concurrency;

enum feature = Feature("simple D client", [
            "This is a test with the C server and a simple D client."
        ]);


alias FeatureContext = Tuple!(DClientWithCServer, "DClientWithCServer", DClientMultithreadingWithCServer,
        "DClientMultithreadingWithCServer", FeatureGroup*, "result");

@safe @Scenario("D Client with C server", [])
class DClientWithCServer
{
    ushort port = 8003;
    int calls = 2;

    @Given("I have a simple sslserver.")
    Document _sslserver() @trusted
    {
        immutable sslserver_start_command = [
            sslserver,
            port.to!string,
            cert,
        ];
        auto ssl_server = spawnProcess(sslserver_start_command);
        Thread.sleep(100.msecs);
        // server_pipe_id = ssl_server.pid;
        return result_ok;
    }

    @Given("I have a simple D sslclient.")
    Document _sslclient()
    {
        const response = echoSSLSocket("localhost", port, "wowo").strip();
        check(response == "wowo", format("Error response not found got: %s", response));

        return result_ok;
    }

    @When("I send many requests repeadtly.")
    Document repeadtly()
    {
        for (int i = 0; i < calls; i++)
        {
            string message = format("test%s", i);
            const response = echoSSLSocket("localhost", port, message).strip();
            // writefln("response:<%s>", response);
            check(message == response, format("Error response not found got: %s", response));
        }
        return result_ok;
    }

    @Then("the sslserver should not chrash.")
    Document chrash() @trusted
    {
        const response = echoSSLSocket("localhost", port, "EOC").strip();
        Thread.sleep(5000.msecs);
        writefln("#####");

        return result_ok;
    }

}

@safe @Scenario("D Client multithreading with C server", [])
class DClientMultithreadingWithCServer
{
    uint number_of_clients = 2;
    const address = "localhost";
    ushort port = 8004;

    @Given("I have a a simple C sslserver.")
    Document _sslserver() @trusted
    {
        // spawn(&__SSLSocketServer, address, port, cert);
        immutable sslserver_start_command = [
            ssltestserver,
            port.to!string,
            cert,
        ];
        auto ssl_server = spawnProcess(sslserver_start_command);
        Thread.sleep(100.msecs);
        // server_pipe_id = ssl_server.pid;
        return result_ok;
    }

    @Given("I have a D sslclient.")
    Document _sslclient() @trusted
    {
        const message = "wowo";
        const response = echoSSLSocket("localhost", port, message).strip();
        check(response == message, format("Error response not found got: %s", response));

        return result_ok;
    }

    @When("I send requests concurrently.")
    Document concurrently() @trusted
    {
        foreach (i; 0 .. number_of_clients)
        {
            spawn(&echoSSLSocketTask, address, port, format("task%s", i), 5, true);
        }
        foreach (i; 0 .. number_of_clients)
        {
            writefln("WAITING for receive %s", i);
            writefln("receive%s, %s", i, receiveOnly!bool);
            // check(receiveOnly!bool, "Received false");
        }

        return result_ok;
    }

    @Then("the sslserver or client should not crash.")
    Document crash() 
    {
        const response = echoSSLSocket("localhost", port, "EOC").strip();
        return result_ok;
    }

}
