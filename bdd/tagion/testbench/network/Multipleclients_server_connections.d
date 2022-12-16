module tagion.testbench.network.Multipleclients_server_connections;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;

import std.concurrency;
import std.socket;
import std.format;

import tagion.basic.Types : Control;
import tagion.network.ServerAPI;
import tagion.network.SSLServiceOptions;
import tagion.testbench.network.SSLSocketTest;
import tagion.hibon.Document;

enum feature = Feature(
            "Test server module with multiple client connection",
            [
            "This test setup an multiple-clients to server module and test the communication between the clients and server."
            ]);

alias FeatureContext = Tuple!(
        AServerModuleWithCapableToServiceMultiClientShouldBeTest, "AServerModuleWithCapableToServiceMultiClientShouldBeTest",
        FeatureGroup*, "result"
);

@safe @Scenario("A server module with capable to service multi client should be test",
        [])
class AServerModuleWithCapableToServiceMultiClientShouldBeTest {
    ServerAPI* server_api;
    uint num_of_clients;
    immutable(ServerOptions) opt;
    this(ServerOptions opt) {
        this.opt = opt;
        num_of_clients = opt.max_queue_length;
    }

    @Given("the server should been stated")
    Document serverShouldBeenStated() {
        auto relay = new TestRelay;
        auto listener = new Socket(AddressFamily.INET, SocketType.STREAM);
        server_api = new ServerAPI(opt, listener, relay);
        server_api.start;
        return result_ok;
    }

    @Given("multiple clients should been stated and connected to the server")
    Document connectedToTheServer() {
        auto sockets = new Socket[num_of_clients];
        auto packages = new TestPackage[num_of_clients];
        auto buf = new ubyte[1024];
        auto address = getAddress(opt.address, opt.port)[0];
        foreach (ref socket; sockets) {
            socket = new Socket(AddressFamily.INET, SocketType.STREAM);
            socket.connect(address);

        }
        foreach (i, ref socket; sockets) {
            packages[i].label = format("message %d", i);
            socket.send(packages[i].toDoc.serialize);
        }
        foreach (i, ref socket; sockets) {
            const size = socket.receive(buf);
            check(size > 0, "Nothing hase been received");
            const received = TestPackage(buf[0 .. size].idup);
            //	const received=buf[0..size];
            check(packages[i].label == received.label,
            format("Expected '%s' but received '%s'", packages[i].label, received.label));
        }
        return Document();
    }

    @When("the clients should send and receive verified data")
    Document andReceiveVerifiedData() {
        return Document();
    }

    @Then("the clients should disconnects to the server.")
    Document disconnectsToTheServer() {
        return Document();
    }

    @Then("the server should verify that all clients has been disconnect")
    Document clientsHasBeenDisconnect() {
        return Document();
    }

    @Then("the server should stop")
    Document theServerShouldStop() @trusted {
        server_api.stop;
        return result_ok;
    }

}
