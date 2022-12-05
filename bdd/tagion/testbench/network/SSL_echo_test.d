module tagion.testbench.network.SSL_echo_test;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;
import tagion.testbench.network.SSL_network_environment : sslclient, sslserver, cert;

import std.process;

enum feature = Feature("simple .c sslserver",
        [
            "This is a test for a very simple .c sslserver in order to understand our problem with connection refused."
        ]);

alias FeatureContext = Tuple!(SendManyRequsts, "SendManyRequsts", FeatureGroup*, "result");

@safe @Scenario("Send many requsts", [])
class SendManyRequsts
{

    string port = "8003";
    string echo_string = "wowowo";

    @Given("I have a simple sslserver")
    Document _sslserver()
    {
        immutable sslserver_start_command = [
            sslserver,
            port,
            cert,
        ];

        auto ssl_server = pipeProcess(sslserver_start_command, Redirect.all, null, Config.detached);

        return result_ok;
    }

    @Given("I have a simple sslclient")
    Document _sslclient()
    {
        immutable sslclient_send_command = [
            sslclient,
            echo_string,
        ];
        auto ssl_client_send = pipeProcess(sslclient_send_command, Redirect.all, null, Config
                .detached);

        return result_ok;
    }

    @When("i send many requests repeatedly")
    Document repeatedly()
    {
        return Document();
    }

    @Then("the sslserver should not chrash.")
    Document chrash()
    {
        return Document();
    }

}
