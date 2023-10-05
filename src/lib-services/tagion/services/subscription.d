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
    uint sendtimeout = 1000;
    uint sendbufsize = 4096;
    mixin JSONCommon;
}

@safe
struct SubscriptionService {
    void task(immutable(SubscriptionServiceOptions) opts) @trusted {
        log.registerSubscriptionTask(thisActor.task_name);
        log("Subscribing to tags");
        foreach (tag; opts.tags) {
            submask.subscribe(tag);
        }
        scope (exit) {
            foreach (tag; opts.tags) {
                submask.unsubscribe(tag);
            }
        }
        log("Subscribed to tags");

        NNGSocket sock = NNGSocket(nng_socket_type.NNG_SOCKET_PUB);
        sock.sendtimeout = opts.sendtimeout.msecs;
        sock.sendbuf = opts.sendbufsize;

        HiRPC hirpc;

        int rc;
        rc = sock.listen(opts.address);
        if (rc != 0) {
            log.error("Could not listen to url %s: %s", opts.address, rc.nng_errstr);
            return;
            // throw new Exception(format("Could not listen to url %s: %s", opts.address, rc.nng_errstr));
        }

        log("Publishing on %s", opts.address);

        void receiveSubscription(Topic topic, string identifier, const(Document) data) @trusted {
            immutable(ubyte)[] payload;

            topic.name.length = 32;
            payload = cast(immutable(ubyte)[]) topic.name;

            HiBON hibon = new HiBON;
            hibon[identifier] = data;
            auto sender = hirpc.log(hibon);
            payload ~= sender.toDoc.serialize;

            rc = sock.send(payload);
            log("%s: %s, %s", identifier, data.length, nng_errstr(rc));
        }

        run(&receiveSubscription);
    }
}

alias SubscriptionServiceHandle = ActorHandle!SubscriptionService;
