/// Service for publishing event subscription
/// https://docs.tagion.org/tech/architecture/LoggerSubscription
module tagion.services.subscription;
@safe:

import core.time : msecs;
import nngd;
import std.array;
import std.format;
import std.variant;
import std.string;

import tagion.actor;
import tagion.basic.Types;
import tagion.communication.HiRPC;
import tagion.hibon.Document;
import tagion.hibon.HiBON;
import tagion.hibon.HiBONRecord;
import tagion.logger;
import tagion.logger.LogRecords;
import tagion.services.exception;
import tagion.services.options : contract_sock_addr;
import tagion.logger.subscription;

/// Options for the subscription service
struct SubscriptionServiceOptions {
    import tagion.json.JSONRecord;

    string tags; /// List of tags that should be enabled separated by a ','
    string address; /// The address which the service should publish events on
    bool enable = true; /// Should the service be started

    private enum SUBSCRIPTION_PREFIX = "SUBSCRIPTION_";

    void setDefault() nothrow {

        address = contract_sock_addr(SUBSCRIPTION_PREFIX);
    }

    void setPrefix(string prefix) nothrow {
        address = contract_sock_addr(prefix ~ SUBSCRIPTION_PREFIX);
    }

    uint sendtimeout = 1000;
    uint sendbufsize = 4096;
    mixin JSONRecord;
}

///
struct SubscriptionService {
    void task(immutable(SubscriptionServiceOptions) opts) @trusted {
        log.registerSubscriptionTask(thisActor.task_name);
        log("Subscribing to tags %s", opts.tags);
        foreach (tag; opts.tags.split(',')) {
            submask.subscribe(tag);
        }
        scope (exit) {
            foreach (tag; opts.tags.split(',')) {
                submask.unsubscribe(tag);
            }
        }
        log("Subscribed to tags");

        NNGSocket sock = NNGSocket(nng_socket_type.NNG_SOCKET_PUB);
        sock.sendtimeout = opts.sendtimeout.msecs;
        sock.sendbuf = opts.sendbufsize;

        HiRPC hirpc;

        int rc = sock.listen(opts.address);
        check!ServiceError(rc == 0, format("Could not listen to url %s: %s", opts.address, rc.nng_errstr));

        log("Publishing on %s", opts.address);

        void receiveSubscription(LogInfo info, const(Document) data) @trusted {
            Buffer payload;

            payload = (info.topic_name ~ info.task_name ~ '\0').representation;

            auto hibon = SubscriptionPayload(info, data);
            auto sender = hirpc.log(hibon);
            payload ~= sender.toDoc.serialize;

            rc = sock.send(payload);
        }

        run(&receiveSubscription);
    }
}
