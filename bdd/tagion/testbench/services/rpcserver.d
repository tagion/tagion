module tagion.testbench.services.rpcserver;

import std.exception;
import std.format;
import tagion.behaviour.Behaviour;
import tagion.testbench.services;
import tagion.tools.Basic;
import tagion.services.options;

mixin Main!(_main);

int _main(string[] _) {
    import tagion.actor;

    enum sock_path = "abstract://" ~ __MODULE__;

    enum input_test = "input_tester_task";
    register(input_test, thisTid);

    TaskNames _task_names;
    _task_names.hirpc_verifier = input_test;

    immutable opts = RPCServerOptions(sock_path);
    TRTOptions trt_opts;
    auto rpc_handle = spawn(immutable(RPCServer)(opts, trt_opts, _task_names), "input_validator_task");
    enforce(waitforChildren(Ctrl.ALIVE), "The rpcserver did not start");

    auto rpcserver_feature = automation!(mixin(__MODULE__));
    rpcserver_feature.SendADocumentToTheSocket(sock_path);
    rpcserver_feature.SendNoneHiRPC(sock_path);
    rpcserver_feature.SendPartialHiBON(sock_path);
    rpcserver_feature.SendBigContract(sock_path);
    rpcserver_feature.run;

    rpc_handle.send(Sig.STOP);
    import core.time;
    import nngd;

    auto sock = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
    int rc = sock.dial(sock_path);
    enforce(rc == 0, format("Failed to dial %s", nng_errstr(rc)));

    enforce(waitforChildren(Ctrl.END), "The rpcserver did not stop");

    return 0;
}

import core.time;
import nngd;
import std.format;
import std.stdio;
import std.typecons : Tuple;
import std.typecons;
import tagion.actor;
import tagion.actor.exceptions;
import tagion.basic.Types;
import tagion.behaviour;
import tagion.communication.HiRPC;
import tagion.hibon.Document;
import tagion.hibon.HiBON;
import tagion.hibon.HiBONBase;
import tagion.hibon.HiBONJSON;
import tagion.logger.LogRecords : LogInfo;
import tagion.logger.Logger;
import tagion.services.rpcserver;
import tagion.services.messages;
import tagion.testbench.actor.util;
import tagion.testbench.tools.Environment;
import tagion.tools.Basic;
import concurrency = tagion.utils.pretend_safe_concurrency;
import tagion.utils.pretend_safe_concurrency;

enum feature = Feature(
            "Rpcserver service",
            [
            "This feature should verify that the rpcserver accepts valid and rejects invalid hirpc inputs over a socket"
            ]);

alias FeatureContext = Tuple!(
        SendADocumentToTheSocket, "SendADocumentToTheSocket",
        SendNoneHiRPC, "SendNoneHiRPC",
        SendPartialHiBON, "SendPartialHiBON",
        SendBigContract, "SendBigContract",
        FeatureGroup*, "result"
);

@safe @Scenario("send a HiRPC submit document to the socket", [])
class SendADocumentToTheSocket {
    NNGSocket sock;
    const string sock_path;
    this(string _sock_path) @trusted {
        sock = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
        sock_path = _sock_path;
    }

    Document sender_doc;

    @Given("a rpcserver")
    Document aInputvalidator() {
        waitforChildren(Ctrl.ALIVE);
        return result_ok;
    }

    @When("we send a HiRPC submit action `Document`")
    Document aSocket() @trusted {
        sock.sendtimeout = msecs(1000);
        sock.sendbuf = 4096;
        sock.recvbuf = 4096;
        int rc = sock.dial(sock_path /* nonblock : true */ );
        check(rc == 0, format("Failed to dial %s", nng_errstr(rc)));
        HiRPC hirpc;
        auto hibon = new HiBON();
        hibon["$test"] = 5;
        const sender = hirpc.submit(hibon);
        sender_doc = sender.toDoc;
        rc = sock.send(sender_doc.serialize);
        check(rc == 0, format("Failed to send %s", nng_errstr(rc)));
        Document received = sock.receive!Buffer;
        check(sock.errno == 0, format("Failed to receive %s", nng_errstr(sock.errno)));
        check(received.length != 0, "Received empty doc");
        auto receiver = hirpc.receive(received);
        check(receiver.isResponse, "Got error response" ~ receiver.toPretty);

        return result_ok;
    }

    @Then("we receive back the Document in our mailbox")
    Document ourMailbox() {
        // The document forwarded to hirpc_verifier
        auto res = concurrency.receiveOnly!(Tuple!(inputDoc, Document));
        check(res[1] == sender_doc, format("The value was not the same as we sent \nsent:%s\nreceived:%s", sender_doc.toPretty, res[1].toPretty));
        return result_ok;
    }
}

@safe @Scenario("send none hirpc document", [])
class SendNoneHiRPC {

    NNGSocket sock;
    const string sock_path;
    this(string _sock_path) @trusted {
        sock = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
        sock_path = _sock_path;
    }

    @Given("a rpcserver")
    Document rpcserver() {
        waitforChildren(Ctrl.ALIVE);

        register("rpcserver_tester", thisTid);

        log.registerSubscriptionTask("rpcserver_tester");
        // submask.subscribe(InputValidatorService.rejected);
        return result_ok;
    }

    @When("we send a document which is not a HiRPC on a socket")
    Document socket() @trusted {
        sock.sendtimeout = msecs(1000);
        sock.sendbuf = 4096;
        sock.recvbuf = 4096;
        sock.recvtimeout = msecs(1000);
        int rc = sock.dial(sock_path);
        check(rc == 0, format("Failed to dial %s", rc));

        auto hibon = new HiBON();
        hibon["$test"] = 5;
        writefln("Buf length %s %s", hibon.serialize.length, Document(hibon.serialize).valid);

        rc = sock.send(hibon.serialize);
        check(rc == 0, format("Failed to send %s", rc));
        return result_ok;
    }

    @Then("the rpcserver rejects")
    Document rejects() {
        Document received = sock.receive!Buffer;
        check(sock.errno == 0, format("Failed to receive %s", nng_errstr(sock.errno)));
        check(received.length != 0, "Received empty buffer");
        check(received !is Document.init, "Received empty document");
        HiRPC hirpc = HiRPC(null);
        auto receiver = hirpc.receive(received);
        check(receiver.isError, "Expected an error");

        return result_ok;
    }

}

@safe @Scenario("send partial HiBON", [])
class SendPartialHiBON {

    NNGSocket sock;
    HiRPC hirpc;
    const string sock_path;
    this(string _sock_path) @trusted {
        sock = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
        sock_path = _sock_path;
        sock.sendtimeout = msecs(1000);
        sock.sendbuf = 4096;
    }

    @Given("a rpcserver")
    Document rpcserver() {
        check(waitforChildren(Ctrl.ALIVE), "waitforChildren");

        register("rpcserver_tester", thisTid);
        log.registerSubscriptionTask("rpcserver_tester");
        /* submask.subscribe(InputValidatorService.rejected); */
        return result_ok;
    }

    @When("we send a `partial_hibon` on a socket")
    Document socket() @trusted {
        int rc = sock.dial(sock_path);
        check(rc == 0, format("Failed to dial %s", nng_errstr(rc)));
        auto hibon = new HiBON();
        hibon["$test"] = 5;
        const sender = hirpc.submit(hibon);
        Document doc = sender.toDoc;
        immutable partial_buf = doc.serialize[0 .. 26].dup;
        writefln("Buf length %s %s", partial_buf.length, Document(partial_buf).valid);
        rc = sock.send(partial_buf);
        check(rc == 0, format("Failed to send %s", nng_errstr(rc)));
        return result_ok;
    }

    @Then("the rpcserver rejects")
    Document rejects() {
        Document received = sock.receive!Buffer;
        check(sock.errno == 0, format("Failed to receive %s", nng_errstr(sock.errno)));
        check(received.length != 0, "Received empty doc");
        auto receiver = hirpc.receive(received);
        check(receiver.isError, "Expected an error");
        return result_ok;
    }

}

@safe @Scenario("send Big Contract",
        [])
class SendBigContract {

    NNGSocket sock;
    HiRPC hirpc;
    const string sock_path;
    this(string _sock_path) @trusted {
        sock = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
        sock_path = _sock_path;
        sock.sendtimeout = msecs(1000);
        sock.sendbuf = 0x4000;
    }


    @Given("a rpcserver")
    Document rpcserver() {
        check(waitforChildren(Ctrl.ALIVE), "waitforChildren");

        register("rpcserver_tester", thisTid);
        log.registerSubscriptionTask("rpcserver_tester");
        /* submask.subscribe(InputValidatorService.rejected); */
        return result_ok;
    }

    @When("we send a `huge contract` on a socket")
    Document socket() @trusted {
        import std.range;
        import std.algorithm;
        int rc = sock.dial(sock_path);
        check(rc == 0, format("Failed to dial %s", nng_errstr(rc)));
        auto hibon = new HiBON();

        string long_string = iota(0,10_000).map!(i => format("%d", i)).join;
        // writefln(long_string);
        hibon["$test"] = long_string;
        const sender = hirpc.submit(hibon);
        auto to_send = sender.toDoc.serialize;
        writefln("long_hibon length=%skb err: %s", to_send.length/1000, Document(to_send).valid);
        rc = sock.send(to_send);
        check(rc == 0, format("Failed to send %s", nng_errstr(rc)));
        return result_ok;
    }

    @Then("we should receive response ok")
    Document ok() {
        Document received = sock.receive!Buffer;
        check(sock.errno == 0, format("Failed to receive %s", nng_errstr(sock.errno)));
        check(received.length != 0, "Received empty doc");
        auto receiver = hirpc.receive(received);
        check(!receiver.isError, format("Did not expect error \n%s", receiver.toPretty));
        
        check(concurrency.receiveTimeout(200.msecs, (inputDoc _, Document __) {}), "should have received a doc");
        return result_ok;
    }

}
