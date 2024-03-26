module tagion.tools.subscriber;

import core.time;
import nngd;
import std.algorithm : countUntil, filter;
import std.algorithm.iteration : splitter;
import std.array : array;
import std.conv;
import std.format;
import std.stdio;
import std.traits;
import std.getopt;
import std.range : empty;
import tagion.basic.Types;
import tagion.basic.Version;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;
import tagion.services.subscription : SubscriptionServiceOptions, SubscriptionPayload;
import tagion.tools.Basic : Main;
import tagion.tools.revision;

import std.exception;
import tagion.crypto.SecureInterfaceNet;
import tagion.communication.HiRPC;
import tagion.utils.Result;
import tagion.logger.ContractTracker : ContractStatus;
import tagion.hibon.HiBONRecord : isRecord;

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

mixin Main!_main;

enum SubFormat {
    pretty, // still json but formatted
    json,
    hibon,
}

int _main(string[] args) {
    immutable program = args[0];

    auto default_sub_opts = SubscriptionServiceOptions();
    default_sub_opts.setDefault();
    string address = default_sub_opts.address;
    bool version_switch;
    string tagsRaw;
    string outputfilename;
    SubFormat output_format;
    string contract;

    auto main_args = getopt(args,
        "v|version", "Print revision information", &version_switch,
        "o|output", "Output filename; if empty stdout is used", &outputfilename,
        "f|format", format("Set the output format default: %s, available %s", SubFormat.init, [
                EnumMembers!SubFormat
            ]), &output_format,
        "address", "Specify the address to subscribe to", &address,
        "tag", "Specify tags to subscribe to", &tagsRaw,
        "contract", "Subscribe to status of a specific contract (base64url hash)", &contract,
    );

    string[] tags;
    if (!tagsRaw.empty) {
        tags = tagsRaw.splitter([',']).filter!((a) => !a.empty).array;
    }

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

    File fout = stdout;
    if (!outputfilename.empty) {
        fout = File(outputfilename, "w");
    }
    scope (exit) {
        if (fout !is stdout) {
            fout.close;
        }
    }

    if (tags.length == 0) {
        stderr.writeln("Subscribing to all tags");
        tags ~= ""; // in NNG subscribing to an empty topic will receive all messages
    }

    writefln("Starting subscriber with tags [%s]", tagsRaw);
    auto sub = Subscription(address, tags);
    auto dialed = sub.dial;
    if (dialed.error) {
        stderr.writefln("Dial error: %s (%s)", dialed.e.message, address);
        return 1;
    }
    stderr.writefln("Listening on, %s", address);

    Result!Document receiveResult() {
        while (true) {
            auto result = sub.receive;

            // Check for contract
            if (!contract.empty && !result.error) {
                const payload = result.get["params"].get!SubscriptionPayload;
                auto doc = payload.data;
                if (doc.isRecord!ContractStatus) {
                    // Drop contact status if it has different hash
                    if (ContractStatus(doc).contract_hash.encodeBase64 != contract) {
                        continue;
                    }
                }
            }

            return result;
        }
    }

    void outputResult(ref Result!Document result) {
        if (result.error) {
            fout.writeln(result.e);
        }
        else {
            final switch (output_format) {
            case SubFormat.pretty:
                fout.writeln(result.get.toPretty);
                break;
            case SubFormat.json:
                fout.writeln(result.get.toJSON);
                break;
            case SubFormat.hibon:
                fout.rawWrite(result.get.serialize);
                break;
            }
        }
    }

    while (true) {
        auto result = receiveResult;
        outputResult(result);
    }
    return 0;
}
