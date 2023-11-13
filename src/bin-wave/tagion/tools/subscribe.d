module tagion.tools.subscribe;

import core.time;
import nngd;
import std.algorithm : countUntil;
import std.conv;
import std.format;
import std.stdio;
import tagion.basic.Types;
import tagion.basic.Version;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;
import tagion.services.subscription : SubscriptionServiceOptions;
import tagion.tools.Basic;
import tagion.tools.revision;
import tagion.utils.getopt;

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
            stderr.writefln("Dial error, %s: (%s)%s", address, rc, rc.nng_errstr);
            if (rc == nng_errno.NNG_ECONNREFUSED) {
                nng_sleep(msecs(100));
                continue;
            }
            assert(rc == 0);
        }
        stderr.writefln("Listening on, %s", address);

        while (true) {
            auto data = sock.receive!Buffer;
            if (sock.errno != 0 && sock.errno != 5) {
                stderr.writefln("Error string: (%s)%s", sock.errno, nng_errstr(sock.errno));
                continue;
            }

            long index = data.countUntil(cast(ubyte) '\0');
            if (index == -1) {
                continue;
            }

            string tag = cast(immutable(char)[]) data[0 .. index];

            if (data.length > index + 1) {
                auto doc = Document(data[index + 1 .. $]);
                stderr.writefln("%s:\n%s", tag, doc.toPretty);
            }
            else {
                stderr.writefln("%s", tag);
            }
        }
    }
    return 0;
}
