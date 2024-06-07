module tagion.logger.subscription;

@safe:

import core.time;

import std.algorithm;

import tagion.basic.Types;
import tagion.hibon.HiBONRecord;
import tagion.hibon.Document;
import tagion.logger.LogRecords;
import tagion.utils.Result;

import nngd;

/// The package which is published over the subscription socket
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

unittest {
    import tagion.communication.HiRPC;
    import tagion.logger.Logger : Topic;
    static struct MyRecord {
        int a = 5;
        mixin HiBONRecord;
    }

    SubscriptionPayload sub = SubscriptionPayload(LogInfo(Topic("a"), "b", "c"), MyRecord().toDoc);
    const sender = HiRPC(null).action("sub", sub);
    const received_doc = sender.toDoc;
    const received_data = received_doc["$msg"]["params"]["data"].get!MyRecord;

}

struct SubscriptionHandle {
    string address;
    string[] tags;
    uint max_attempts = 5;

    private NNGSocket sock;
    this(string _address, string[] _tags) @trusted nothrow {
        address = _address;
        tags = _tags;
        sock = NNGSocket(nng_socket_type.NNG_SOCKET_SUB);
        sock.recvtimeout = 100.seconds;
        foreach (tag; tags) {
            sock.subscribe(tag);
        }
    }

    private bool _isDial;

    Result!bool dial() @trusted nothrow {
        int rc;
        foreach (_; 0 .. max_attempts) {
            rc = sock.dial(address);
            switch (rc) with (nng_errno) {
            case NNG_OK:
                _isDial = true;
                return result(true);
            case NNG_ECONNREFUSED:
                nng_sleep(msecs(100));
                continue;
            default:
                return Result!bool(false, nng_errstr(rc));
            }
        }
        return Result!bool(false, nng_errstr(rc));
    }

    Result!Document receive() @trusted nothrow {
        alias _Result = Result!Document;
        if (!_isDial) {
            auto d = dial;
            if (d.error) {
                return _Result(d.e);
            }
        }

        Buffer data;
        foreach (_; 0 .. max_attempts) {
            data = sock.receive!Buffer;
            if (sock.errno != nng_errno.NNG_OK && sock.errno != nng_errno.NNG_ETIMEDOUT) {
                break;
            }
        }

        if (sock.errno != 0) {
            return _Result(nng_errstr(sock.errno));
        }

        if (data.length == 0) {
            return _Result("Received empty data");
        }

        long index = data.countUntil(cast(ubyte) '\0');
        if (index == -1) {
            return _Result("Received data does not begin with a tag");
        }

        if (data.length <= index + 1) {
            return _Result("Received data does not contain a document");
        }

        return _Result(Document(data[index + 1 .. $]));
    }
}
