module tagion.testbench.network.SSL_echo_test;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;
import tagion.testbench.network.SSL_network_environment : sslclient, sslserver, cert;

import std.process;
import std.stdio;
import std.format;
import std.array;
import std.conv;

enum feature = Feature("simple .c sslserver",
        [
            "This is a test for a very simple .c sslserver in order to understand our problem with connection refused."
        ]);

alias FeatureContext = Tuple!(SendManyRequsts, "SendManyRequsts", FeatureGroup*, "result");

@safe @Scenario("Send many requsts", [])
class SendManyRequsts
{

    string port = "8003";
    int calls = 10;

    @Given("I have a simple sslserver")
    Document _sslserver()
    {
        immutable sslserver_start_command = [
            sslserver,
            port,
            cert,
        ];
        writefln("%s", sslserver_start_command.join(" "));

        auto ssl_server = pipeProcess(sslserver_start_command);

        return result_ok;
    }

    @Given("I have a simple sslclient")
    Document _sslclient() @trusted
    {
        immutable sslclient_send_command = [
            sslclient,
            "localhost",
            port.to!string,
        ];
        writefln("%s", sslclient_send_command.join(" "));

        auto sslclient_send = pipeProcess(sslclient_send_command);
        sslclient_send.stdin.writeln("test");
        sslclient_send.stdin.flush();
        sslclient_send.stdin.close();

        wait(sslclient_send.pid);
        const testing = sslclient_send.stdout.readln();
        writefln("testwowowo = %s", testing);
        
        return result_ok;
    }

    @When("i send many requests repeatedly")
    Document repeatedly()
    {
        // for (int i = 0; i < calls; i++)
        // {
        //     writefln("sending %s", i);
        //     immutable sslclient_send_command = [
        //         sslclient,
        //         "localhost",
        //         port.to!string,
        //     ];

        //     writefln("%s", sslclient_send_command.join(" "));

        //     auto sslclient_send = pipeProcess(sslclient_send_command);
        //     writefln("%s", sslclient_send.stdout);

        // }

        return Document();
    }

    @Then("the sslserver should not chrash.")
    Document chrash()
    {

        immutable sslclient_send_command = [
            sslclient,
            "localhost",
            port.to!string,
        ];
        writefln("%s", sslclient_send_command.join(" "));

        auto sslclient_send = pipeProcess(sslclient_send_command);
        sslclient_send.stdin.writeln("EOC");
        sslclient_send.stdin.flush();
        sslclient_send.stdin.close();
        writefln("%s", sslclient_send.stdout);
        wait(sslclient_send.pid);

        return result_ok;
        return Document();
    }

}
