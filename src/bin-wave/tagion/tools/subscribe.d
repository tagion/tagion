module tagion.tools.subscribe;

import std.stdio;
import std.conv;
import std.format;

import core.time;

import tagion.tools.Basic;
import tagion.utils.getopt;
import tagion.basic.Version;
import tagion.tools.revision;

import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;

import nngd;

mixin Main!(_main);

int _main(string[] args) {
    immutable program = args[0];

    string address = "abstract://tagion_subscription";
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
        tagionGetoptPrinter(
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

        foreach (tag; tags) {
            sock.subscribe(tag);
        }

        while (1) {
            int rc = sock.dial(address);
            if (rc == 0) {
                break;
            }
            stderr.writefln("Dial error, %s: %s", address, rc);
            if (rc == nng_errno.NNG_ECONNREFUSED) {
                nng_sleep(msecs(100));
                continue;
            }
            assert(rc == 0);
        }

        while (1) {
            auto data = sock.receive!(immutable(ubyte)[]);

            if (sock.errno != 0) {
                stderr.writefln("Error string: %s", nng_errstr(sock.errno));
            }
            else if (data.length >= 32) {
                string tag = data[0 .. 32].to!string;
                auto doc = Document(data[33 .. $]);
                stderr.writefln("%s:\n%s", tag, doc.toPretty);
                // stderr.writefln("%s: No document", tag);
            }
        }
    }
    return 0;
}
