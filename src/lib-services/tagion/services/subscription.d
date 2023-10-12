module tagion.services.subscription;
@safe:

import std.variant;
import std.array;

import tagion.actor;
import tagion.logger;
import tagion.logger.LogRecords;
import tagion.hibon.Document;
import tagion.hibon.HiBON;
import tagion.communication.HiRPC;
import tagion.hibon.HiBONRecord;

import nngd;
import core.time : msecs;

struct SubscriptionServiceOptions {
    import tagion.utils.JSONCommon;

    string tags;
    string address;

    import tagion.services.options : contract_sock_addr;
    void setDefault() nothrow {
        address = contract_sock_addr("SUBSCRIPTION_");
    }

    uint sendtimeout = 1000;
    uint sendbufsize = 4096;
    mixin JSONCommon;
}

@recordType("sub_payload")
struct SubscriptionPayload {
    @label("topic") string topic_name;
    @label("task") string task_name;
    @label("symbol") string symbol_name;
    @label("data") Document data;

    mixin HiBONRecord!(q{
            this(LogInfo info, const(Document) data) {
                this.topic_name = info.topic_name;
                this.task_name = info.task_name;
                this.symbol_name = info.symbol_name;
                this.data = data;
            }
    });
}

struct SubscriptionService {
    void task(immutable(SubscriptionServiceOptions) opts) @trusted {
        log.registerSubscriptionTask(thisActor.task_name);
        log("Subscribing to tags");
        foreach (tag; opts.tags.split(':')) {
            submask.subscribe(tag);
        }
        scope (exit) {
            foreach (tag; opts.tags.split(':')) {
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
            throw new Exception(format("Could not listen to url %s: %s", opts.address, rc.nng_errstr));
        }

        log("Publishing on %s", opts.address);

        void receiveSubscription(LogInfo info, const(Document) data) @trusted {
            immutable(ubyte)[] payload;

            payload = cast(immutable(ubyte)[])(info.topic_name ~ '\0');

            auto hibon = SubscriptionPayload(info, data);
            auto sender = hirpc.log(hibon);
            payload ~= sender.toDoc.serialize;

            rc = sock.send(payload);
        }

        run(&receiveSubscription);
    }
}

alias SubscriptionServiceHandle = ActorHandle!SubscriptionService;
