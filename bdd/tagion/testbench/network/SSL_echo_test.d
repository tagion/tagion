module tagion.testbench.network.SSL_echo_test;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;
import tagion.testbench.network.SSL_network_environment : sslclient, sslserver, cert, client_send;

import std.process;
import std.stdio;
import std.format;
import std.array;
import std.conv;
import std.string : strip;
import core.thread;

enum feature = Feature("simple .c sslserver",
        [
            "This is a test for a very simple .c sslserver in order to understand our problem with connection refused."
        ]);

alias FeatureContext = Tuple!(SendManyRequsts, "SendManyRequsts", FeatureGroup*, "result");

@safe @Scenario("Send many requsts", [])
class SendManyRequsts
{
    ushort port = 8003;
    int calls = 100;

    @Given("I have a simple sslserver")
    Document _sslserver()
    {
        immutable sslserver_start_command = [
            sslserver,
            port.to!string,
            cert,
        ];
        // writefln("%s", sslserver_start_command.join(" "));

        auto ssl_server = spawnProcess(sslserver_start_command);
        return result_ok;
    }

    @Given("I have a simple sslclient")
    Document _sslclient() 
    {
        const response = client_send("wowo", port);

        // writefln("response = %s", response);

        check(response == "wowo", "Message not received");

        return result_ok;
    }

    @When("i send many requests repeatedly")
    Document repeatedly() 
    {
        for (int i = 0; i < calls; i++)
        {
            immutable message = format("test%s", i);

            const response = client_send(message, port);

            check(response == message, "Message not received");
            // writefln("response = %s", response);

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
