module tagion.testbench.network.Multipleclients_server_connections;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;

import std.concurrency;
import std.socket;
import std.format;
import std.stdio;
import core.thread : Thread;
import core.time;

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
        AServerModuleWhichShouldBeCapableOfServicingMultipleClients, "AServerModuleWhichShouldBeCapableOfServicingMultipleClients",
        FeatureGroup*, "result"
);

@safe @Scenario("A server module which should be capable of servicing multiple clients",
        [])
class AServerModuleWhichShouldBeCapableOfServicingMultipleClients {
    Tid server_tid;
    uint num_of_clients;
    string task_name = "test_server";
    const bool ssl_enable;
    immutable(SSLServiceOptions) opts;
    this(SSLServiceOptions opts, bool ssl_enable) {
        this.opts = opts;
        this.ssl_enable = ssl_enable;
        num_of_clients = opts.server.max_queue_length;
    }

    @trusted
    @Given("the server should been stated")
    Document stated() {
        server_tid = spawn(&testFiberServerTask, opts, task_name, ssl_enable);
        check(receiveOnly!Control is Control.LIVE, "Server task did not start correctly");
        writefln("Server started");
        Thread.sleep(200.msecs);
        return result_ok;
    }

    @trusted
    @Given("multiple clients should been stated and connected to the server in sequence")
    Document sequence() {
        auto sockets = new Socket[num_of_clients];
        auto packages = new TestPackage[num_of_clients];
        auto buf = new ubyte[1024];
        auto address = getAddress(opts.server.address, opts.server.port)[0];
        foreach (ref socket; sockets) {
            socket = createClient(AddressFamily.INET, SocketType.STREAM, ssl_enable);
            io.writefln("Before connect");
            socket.connect(address);
            io.writefln("After connect");

        }
        foreach (i, ref socket; sockets) {
            packages[i].label = format("message %d", i);
            socket.send(packages[i].toDoc.serialize);
        }
        foreach (i, ref socket; sockets) {
            const size = socket.receive(buf);
            check(size > 0, "Nothing hase been received");
            const doc = Document(buf[0 .. size].idup);
            const received = TestPackage(doc);
            check(packages[i].label == received.label,
            format("Expected '%s' but received '%s'", packages[i].label, received.label));
        }
        version (none) {
            foreach (i, ref socket; sockets) {
                packages[i].label = format("new message %d", i);
                socket.send(packages[i].toDoc.serialize);
            }
            foreach (i, ref socket; sockets) {
                const size = socket.receive(buf);
                check(size > 0, "Nothing hase been received");
                const doc = Document(buf[0 .. size].idup);
                const received = TestPackage(doc);
                check(packages[i].label == received.label,
                format("Expected '%s' but received '%s'", packages[i].label, received.label));
            }
        }
        foreach (i, ref socket; sockets) {
            socket.shutdown(SocketShutdown.BOTH);
        }

        return result_ok;
    }

    @Given("multiple clients should been started at the same time (in parallel).")
    Document parallel() {
        return Document();
    }

    @When("the clients should send and receive verified data")
    Document data() {
        return Document();
    }

    @Then("the clients should disconnects to the server.")
    Document server() {
        return Document();
    }

    @Then("the server should verify that all clients has been disconnect")
    Document disconnect() {
        return Document();
    }

    @Then("the server should stop")
    Document stop() @trusted {
//        Thread.sleep(10.seconds);
  //      writefln("Before stop send to the server task");
        server_tid.send(Control.STOP);
  //      writefln("Stop send to the server task");
        check(receiveOnly!Control == Control.END, "Server task did not finish correctly");
   //     writefln("End received from the server task");
  //      Thread.sleep(1.seconds);
        return result_ok;
    }

}
