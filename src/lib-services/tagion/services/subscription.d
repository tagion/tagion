module tagion.services.subscription;

import std.variant;
import std.conv;

import tagion.actor;
import tagion.logger;
import tagion.hibon.Document;
import tagion.hibon.HiBON;
import tagion.communication.HiRPC;

import nngd;
import core.time : msecs;

struct SubscriptionServiceOptions {
    import tagion.utils.JSONCommon;

    string address = "abstract://tagion_subscription";
    mixin JSONCommon;
}

@safe
struct SubscriptionService {
    void task(SubscriptionServiceOptions opts) @trusted {
        NNGSocket sock = NNGSocket(nng_socket_type.NNG_SOCKET_PUB);
        sock.sendtimeout = 1000.msecs;
        sock.sendbuf = 4096;

        void receiveSubscription(Topic topic, string identifier, const(Document) data) @trusted {
            immutable(ubyte)[] payload;
            topic.name.length = 32;
            payload = topic.name.to!(immutable(ubyte)[]);

            const s = SubscriptionPayload(data);
            payload ~= s.toDoc.serialize;
            int rc = sock.send(payload);
        }

        int rc = sock.listen(opts.address);
        if (rc != 0) {
            throw new Exception(format("Could not listen to url %s: %s", opts.address, rc.nng_errstr));
        }
        run(&receiveSubscription);
    }
}

/// Make a hirpc
import tagion.hibon.HiBONRecord;

struct SubscriptionPayload {
    Document data;
    mixin HiBONRecord;
}
