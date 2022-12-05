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
import std.string : strip;

enum feature = Feature("simple .c sslserver",
        [
            "This is a test for a very simple .c sslserver in order to understand our problem with connection refused."
        ]);

alias FeatureContext = Tuple!(SendManyRequsts, "SendManyRequsts", FeatureGroup*, "result");

@safe @Scenario("Send many requsts", [])
class SendManyRequsts
{

    string port = "8003";
    int calls = 10000;
    Pid server_pipe_id;

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
        server_pipe_id = ssl_server.pid;
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
        sslclient_send.stdin.writeln("wowo");
        sslclient_send.stdin.flush();
        sslclient_send.stdin.close();

        wait(sslclient_send.pid);
        const stdout_message = sslclient_send.stdout.readln().strip();
        writefln("stdout_message = %s", stdout_message);

        check(stdout_message == "wowo", "Message not received");

        return result_ok;
    }

    @When("i send many requests repeatedly")
    Document repeatedly() @trusted
    {
        for (int i = 0; i < calls; i++)
        {
            immutable message = format("test%s", i);
            immutable sslclient_send_command = [
                sslclient,
                "localhost",
                port.to!string,
            ];
            writefln("%s", sslclient_send_command.join(" "));

            auto sslclient_send = pipeProcess(sslclient_send_command);
            sslclient_send.stdin.writeln(message);
            sslclient_send.stdin.flush();
            sslclient_send.stdin.close();

            wait(sslclient_send.pid);
            const stdout_message = sslclient_send.stdout.readln().strip();
            check(stdout_message == message, "Message not received");
            writefln("stdout_message = %s", stdout_message);            
           
        }
        return result_ok;
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
        wait(server_pipe_id);

        return result_ok;
    }

}
