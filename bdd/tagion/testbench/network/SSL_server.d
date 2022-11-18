module tagion.testbench.network.SSL_server;
// Default import list for bdd
import tagion.behaviour.Behaviour;
import tagion.behaviour.BehaviourFeature;
import tagion.behaviour.BehaviourException;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;
import std.typecons;
import std.outbuffer;
import std.format;
import std.stdio;

import tagion.network.SSLOptions;

import tagion.testbench.network.TestSSLServer;

enum feature = Feature(
            "SSL server",
            ["",
            "This test setup an multi-client SSL server",
            "",
            ""]);

alias FeatureContext = Tuple!(
        CreatesASSLCertificate, "CreatesASSLCertificate",
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
     writefln("%s", opt);
        const exit_code = configureOpenSSL(opt, bout);
       writefln("<%s>", bout.toString); 
        check(exit_code == 0, format("Certificate failed with exit code %d and stdout %s", exit_code, bout));
        return Document();
    }

    @When("the certificate has been created")
    Document created() {
        check(false, "Check for 'created' not implemented");
        return Document();
    }

    @Then("check that the SSL certificate is valid")
    Document valid() {
        check(false, "Check for 'valid' not implemented");
        return Document();
    }
}
