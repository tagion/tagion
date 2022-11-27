module tagion.testbench.network.SSL_server;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import std.file : exists;
import std.format;

import tagion.network.SSLOptions;

import tagion.testbench.network.TestSSLServer;

enum feature = Feature(
            "SSL server",
            ["This test setup an multi-client SSL server"]);

alias FeatureContext = Tuple!(
        CreatesASSLCertificate, "CreatesASSLCertificate",
        FeatureGroup*, "result"
);

@safe @Scenario("creates a SSL certificate",
        [])
class CreatesASSLCertificate {
    const SSLOptions opt;

    this(const(SSLOptions) opt) pure nothrow {
        this.opt = opt;
    }

    @Given("the domain information of a SSL certificate")
    Document certificate() {
        configureOpenSSL(opt.openssl);
        return result_ok;
    }

    @When("the certificate has been created")
    Document created() {
        check(!opt.openssl.certificate.exists || !opt.openssl.private_key.exists,
                format("pem files %s and %s has not been created",
                opt.openssl.certificate.exists, opt.openssl.private_key.exists));
        return result_ok;
    }

    @Then("check that the SSL certificate is valid")
    Document valid() {
        return Document();
    }
}
