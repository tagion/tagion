module tagion.testbench.services.subscription_test;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import core.time;
import std.algorithm;
import std.stdio;

import tagion.communication.HiRPC;
import tagion.actor;
import tagion.hibon.HiBON;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;
import tagion.logger;
import tagion.tools.Basic;
import tagion.basic.Types;
import tagion.services.subscription;
import nngd;

mixin Main!_main;

int _main(string[] _) {
    /* alias subscription_test = tagion.testbench.services.subscription_test; */
    alias subscription_test = mixin(__MODULE__);

    auto subscription_feature = automation!subscription_test;
    subscription_feature.ReceiveSubscribedTopicsOnASocket("abstract://test_subscription");
    subscription_feature.run;

    return 0;
}

enum feature = Feature(
        "Subscription service",
        ["This feature verifies the basic features of the subscription service"]);

alias FeatureContext = Tuple!(
    ReceiveSubscribedTopicsOnASocket, "ReceiveSubscribedTopicsOnASocket",
    FeatureGroup*, "result"
);

@Scenario("receive subscribed topics on a socket",
    [])
class ReceiveSubscribedTopicsOnASocket {

    ActorHandle sub_handle;
    NNGSocket sock;
    immutable(SubscriptionServiceOptions) sub_opts;

    Topic topic_subscribed = "tag_subscribed";
    Topic topic_unsubscribed = "tag_unsubscribed";

    string address;

    this(string address) @trusted {
        // Only the tags passed in subscription service options are enabled
        this.address = address;
        sub_opts = SubscriptionServiceOptions(topic_subscribed.name, address);
        sock = NNGSocket(nng_socket_type.NNG_SOCKET_SUB);
    }

    @Given("a subscription service")
    Document aSubscriptionService() {

        // Spawn the subscription task which open the nng pub socket
        sub_handle = spawn!SubscriptionService("sub_test_task", sub_opts);
        check(waitforChildren(Ctrl.ALIVE, 5.seconds), "Service didn't start");

        // Connect a client socket
        sock.recvtimeout = msecs(1000);
        int rc = sock.dial(address);
        check(rc == 0, "Failed to dial: " ~ nng_errstr(rc));

        // We set a taskname for this thread so we can see who produced the subscription event
        thisActor.task_name = "subscriber_tester";

        return result_ok;
    }

    @When("we subscribe to a topic which is enabled we should receive a document")
    Document shouldReceiveADocument() {
        sock.subscribe(topic_subscribed.name);

        auto hibon = new HiBON;
        hibon["status"] = "world domination achieved";
        log.event(topic_subscribed, __FUNCTION__, Document(hibon));

        Buffer data = sock.receive!Buffer;
        check(sock.errno == 0, "Did not receive subscription: " ~ nng_errstr(sock.errno));

        // The tag name and the document is separated by a null byte
        long index = data.countUntil('\0');
        check(index > 0, "Received data does not begin with a tag");
        check(data.length > index + 1, "Received data does not contain a document");
        const doc = Document(data[index + 1 .. $]);
        writefln("received\n%s", doc.toPretty);
        const hirpc = HiRPC(null);
        const receiver = hirpc.receive(doc);
        const sub_paylod = SubscriptionPayload(receiver.method.params);

        check(sub_paylod.task_name == thisActor.task_name, "The taskname in sub_paylod was different");
        check(sub_paylod.topic_name == topic_subscribed.name, "The topic name in sub_paylod was different");
        check(sub_paylod.symbol_name == __FUNCTION__, "The sumbol name in sub_paylod was different");
        check(sub_paylod.data["status"].get!string == hibon["status"].get!string, "Sub payload was not the same");

        sock.unsubscribe(topic_subscribed.name);

        return result_ok;
    }

    @When("we subscribe to a topic which is not enabled we should not receive a document")
    Document notReceiveADocument() {
        // We subscribe to the tag, but it's not enabled in the subscription service.
        // So no event will be dispatched
        sock.subscribe(topic_subscribed.name);

        auto hibon = new HiBON;
        hibon["status"] = "world domination achieved";
        log.event(topic_unsubscribed, __FUNCTION__, Document(hibon));

        Buffer _ = sock.receive!Buffer;
        check(sock.errno == nng_errno.NNG_ETIMEDOUT, "Subscription should've timed out: " ~ nng_errstr(sock.errno));

        return result_ok;
    }

    @Then("we stop the service")
    Document weStopTheService() {
        sub_handle.send(Sig.STOP);
        check(waitforChildren(Ctrl.END, 5.seconds), "Service did not stop");

        return result_ok;
    }

}
