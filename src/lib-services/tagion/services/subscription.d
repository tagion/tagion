module tagion.services.subscription;

import std.variant;

import tagion.actor;
import tagion.logger;
import tagion.hibon.Document;
import tagion.hibon.HiBON;
import tagion.communication.HiRPC;

import nngd;
import core.time : msecs;

struct SubscriptionServiceOptions {
    import tagion.utils.JSONCommon;

    string[] tags;
    string address = "abstract://tagion_subscription";
    mixin JSONCommon;
}

@safe
struct SubscriptionService {
    void task(immutable(SubscriptionServiceOptions) opts) @trusted {

        log.registerSubscriptionTask(thisActor.task_name);
        foreach (tag; opts.tags) {
            submask.subscribe(tag);
        }

        NNGSocket sock = NNGSocket(nng_socket_type.NNG_SOCKET_PUB);
        sock.sendtimeout = 1000.msecs;
        sock.sendbuf = 4096;

        HiRPC hirpc;

        void receiveSubscription(Topic topic, string identifier, const(Document) data) @trusted {
            immutable(ubyte)[] payload;
            topic.name.length = 32;
            payload = cast(immutable(ubyte)[]) topic.name;

            HiBON hibon = new HiBON;
            hibon[identifier] = data;
            auto sender = hirpc.log(hibon);
            payload ~= sender.toDoc.serialize;
            int rc = sock.send(payload);
        }

        int rc = sock.listen(opts.address);
        if (rc != 0) {
            throw new Exception(format("Could not listen to url %s: %s", opts.address, rc.nng_errstr));
        }
        run(&receiveSubscription);
    }
}
