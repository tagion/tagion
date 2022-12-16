module tagion.testbench.network.Multipleclients_server_connections;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;

import std.concurrency;
import std.socket;
import std.format;
import std.stdio;
import core.thread;

import tagion.basic.Types : Control;
import tagion.network.ServerAPI;
import tagion.network.SSLServiceOptions;
import tagion.testbench.network.SSLSocketTest;
import tagion.hibon.Document;
import io = std.stdio;

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
    Tid server_tid;
    uint num_of_clients;
    string task_name = "test_server";
    immutable(ServerOptions) opts;
    this(ServerOptions opts) {
        this.opts = opts;
        num_of_clients = opts.max_queue_length;
    }

    @trusted
    @Given("the server should been stated")
    Document serverShouldBeenStated() {
        server_tid = spawn(&testServerTask, opts, task_name);
        check(receiveOnly!Control is Control.LIVE, "Server task did not start correctly");
        return result_ok;
    }

    @trusted
    @Given("multiple clients should been stated and connected to the server")
    Document connectedToTheServer() {
        auto sockets = new Socket[num_of_clients];
        auto packages = new TestPackage[num_of_clients];
        auto buf = new ubyte[1024];
        auto address = getAddress(opts.address, opts.port)[0];
        foreach (ref socket; sockets) {
            socket = new Socket(AddressFamily.INET, SocketType.STREAM);
            io.writefln("Before connect");
            socket.connect(address);
            io.writefln("After connect");

        }
        foreach (i, ref socket; sockets) {
            packages[i].label = format("message %d", i);
            writefln("%J", packages[i]);
            socket.send(packages[i].toDoc.serialize);
        }
        foreach (i, ref socket; sockets) {
            const size = socket.receive(buf);
            check(size > 0, "Nothing hase been received");
            const doc = Document(buf[0 .. size].idup);
            const received = TestPackage(doc);
            //	const received=buf[0..size];
            check(packages[i].label == received.label,
            format("Expected '%s' but received '%s'", packages[i].label, received.label));
        }
        return result_ok;
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
        Thread.sleep(10.seconds);
        server_tid.send(Control.STOP);
        check(receiveOnly!Control == Control.END, "Server tash did not finish correctly");
        return result_ok;
    }

}
