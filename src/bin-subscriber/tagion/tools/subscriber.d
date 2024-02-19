module tagion.tools.subscribe;

import core.time;
import nngd;
import std.algorithm : countUntil;
import std.conv;
import std.format;
import std.stdio;
import std.getopt;
import tagion.basic.Types;
import tagion.basic.Version;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;
import tagion.services.subscription : SubscriptionServiceOptions;
import tagion.tools.Basic : Main;
import tagion.tools.revision;

import std.exception;
import tagion.crypto.SecureInterfaceNet;
import tagion.communication.HiRPC;
import tagion.utils.Result;

struct Subscription {
    string address;
    string[] tags;
    SecureNet net;
    uint max_attempts = 5;

    private NNGSocket sock;
    this(string _address, string[] _tags, SecureNet _net = null) @trusted nothrow {
        address = _address;
        tags = _tags;
        net = _net;
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

        try {
            auto _doc = Document(data[index + 1 .. $]);
            auto _receiver = HiRPC.Receiver(net, _doc);
            return result(_receiver.message); // This could be a hirpc error
        }
        catch (Exception e) {
            return _Result(e);
        }
    }
}

mixin Main!(_main);

int _main(string[] args) {
    immutable program = args[0];

    auto default_sub_opts = SubscriptionServiceOptions();
    default_sub_opts.setDefault();
    string address = default_sub_opts.address;
    bool version_switch;
    string[] tags;
    bool watch;

    auto main_args = getopt(args,
            "v|version", "Print revision information", &version_switch,
            "address", "specify the address to subscribe to", &address,
            "w|watch", "Watch logs", &watch,
            "tag", "Which tags to subscribe to", &tags,
    );

    if (main_args.helpWanted) {
        defaultGetoptPrinter(
                format("Help information for %s\n", program),
                main_args.options
        );
        return 0;
    }
    if (version_switch) {
        revision_text.writeln;
        return 0;
    }

    if (watch) {
        NNGSocket sock = NNGSocket(nng_socket_type.NNG_SOCKET_SUB);
        sock.recvtimeout = msecs(1000);

        if (tags.length == 0) {
            stderr.writeln("No tags specified");
            return 1;
        }

        auto sub = Subscription(address, tags);
        auto dialed = sub.dial;
        if (dialed.error) {
            stderr.writefln("Dial error: %s (%s)", dialed.e.message, address);
            return 1;
        }
        stderr.writefln("Listening on, %s", address);

        while (true) {
            auto result = sub.receive;
            if (result.error) {
                stderr.writeln(result.e);
            }
            else {
                writeln(result.get.toPretty);
            }
        }
    }
    return 0;
}
