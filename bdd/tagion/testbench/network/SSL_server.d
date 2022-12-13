module tagion.testbench.network.SSL_server;
// Default import list for bdd
import std.typecons;
import std.outbuffer;
import std.format;
import std.stdio;
import std.file : exists;
import std.concurrency;
import core.thread.osthread : Thread;
import core.time;
import std.socket;

import tagion.behaviour.Behaviour;
import tagion.behaviour.BehaviourResult;
import tagion.behaviour.BehaviourFeature;
import tagion.behaviour.BehaviourException;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;
import tagion.basic.Types : Control;

import std.socket : InternetAddress, Socket, SocketSet, SocketShutdown, shutdown, AddressFamily;
import tagion.network.SSLOptions;
import tagion.network.SSLSocket;
import tagion.network.SSLServiceAPI;

import tagion.testbench.network.TestSSLServer;

enum feature = Feature(
            "SSL server",
            ["",
            "This test setup an multi-client SSL server",
            "",
            ""]);

alias FeatureContext = Tuple!(
        CreatesASSLCertificate, "CreatesASSLCertificate",
        SSLServiceUsingASpecifiedCertificate, "SSLServiceUsingASpecifiedCertificate",
        FeatureGroup*, "result"
);

@safe @Scenario("creates a SSL certificate",
        [])
class CreatesASSLCertificate {
    const OpenSSL opt;

    this(const(OpenSSL) opt) pure nothrow {
        this.opt = opt;
    }

    @Given("the domain information of a SSL certificate")
    Document certificate() {
        auto bout = new OutBuffer;
        const exit_code = configureOpenSSL(opt, bout);
        check(exit_code == 0, format("Certificate failed with exit code %d and stdout %s", exit_code, bout));
        return result_ok;
    }

    @When("the certificate has been created")
    Document created() {
        check(opt.certificate.exists && opt.private_key.exists, "The pem files has not been generated");
        return result_ok;
    }

    @Then("check that the SSL certificate is valid")
    Document valid() {
        auto _listener = new SSLSocket(
                AddressFamily.INET,
                SocketType.STREAM,
                opt.certificate,

                opt.private_key);
        scope (exit) {
            _listener.close;
        }
        return result_ok;
    }

}

@safe @Scenario("SSL service using a specified certificate",
        [])
class SSLServiceUsingASpecifiedCertificate {
    immutable SSLOptions opt;
    string task_name;
    this(const(SSLOptions) opt, string task_name) {
        this.opt = opt;
        this.task_name = task_name;
        writeln("---- ---- ----");
    }

    ~this() {
        //      listener.close;
    }

    SSLSocket listener;
    @Given("certificate are available open a server")
    Document aServer() @trusted {
        listener = new SSLSocket(
                AddressFamily.INET,
                SocketType.STREAM,
                opt.ssl.certificate,
                opt.ssl.private_key);
        simpleSSLServer(opt, listener);
        return result_ok;
    }

    @When("the server has respond to a number of request")
    Document ofRequest() @trusted {
        //        Thread.sleep(200.msecs);
        //        test_server_tid.send(Control.STOP);
        return result_ok;
    }

    @Then("close the server")
    Document theServer() {
        //        check(false, "Check for 'theServer' not implemented");
        return result_ok;
    }

}
