module tagion.tools.subscriber;

import core.time;
import core.thread;

import std.algorithm : countUntil;
import std.array : array;
import std.conv;
import std.format;
import std.stdio;
import std.getopt;
import std.range : empty;
import std.exception;

import tagion.basic.Types;
import tagion.basic.Version;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;
import tagion.services.subscription : SubscriptionServiceOptions;
import tagion.crypto.SecureInterfaceNet;
import tagion.communication.HiRPC;
import tagion.utils.pretend_safe_concurrency;
import tagion.logger.ContractTracker : ContractStatus;
import tagion.logger.subscription;
import tagion.hibon.HiBONRecord : isRecord;
import tagion.tools.revision;
import tagion.tools.toolsexception;
import tools = tagion.tools.Basic;

import nngd;

mixin tools.Main!_main;

__gshared File fout;
shared bool stop;
static bool delegate(Document) nothrow filter_func = (Document) => true;


int _main(string[] args) {
    try {
        return __main(args);
    }
    catch (Exception e) {
        tools.error(e);
        return 1;
    }
}

int __main(string[] args) {
    immutable program = args[0];

    auto default_sub_opts = SubscriptionServiceOptions();
    default_sub_opts.setDefault();
    string[] addresses = [default_sub_opts.address];
    bool version_switch;
    string[] tags;
    string outputfilename;
    string contract;

    auto main_args = getopt(args,
        "version", "Print revision information", &version_switch,
        "v|verbose", "Enable verbose print-out", &tools.__verbose_switch,
        "o|output", "Output filename; if empty stdout is used", &outputfilename,
        "address", "Specify the address to subscribe to", &addresses,
        "tag", "Specify tags to subscribe to", &tags,
        "contract", "Subscribe to status of a specific contract (base64url hash)", &contract,
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

    check(!addresses.empty, "No addresses specified");

    if (outputfilename.empty) {
        fout = stdout;
    }
    else {
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
    else {
        stderr.writefln("Subscribing to tags %s", tags);
    }

    if(!contract.empty) {
        filter_func = (Document hirpc_doc) nothrow {
                try {
                const payload = hirpc_doc["$msg"].get!Document["params"].get!SubscriptionPayload;
                auto doc = payload.data;
                if (doc.isRecord!ContractStatus) {
                    // Drop contact status if it has different hash
                    if (ContractStatus(doc).contract_hash.encodeBase64 != contract) {
                        return true;
                    }
                }
                } catch(Exception) {}
                return false;
        };
    }

    scope(exit) {
        stop = true;
    }

    immutable tags_ = cast(immutable)tags;
    foreach(address; addresses) {
        spawn(&subscription_handle_worker, address, tags_);
    }

    thread_joinAll;

    return 0;
}

void sync_write(Document doc) {
    synchronized {
        fout.rawWrite(doc.serialize);
    }
}

void subscription_handle_worker(string address, immutable(string[]) tags) {
    try {
        NNGSocket sock = NNGSocket(nng_socket_type.NNG_SOCKET_SUB);
        int rc;
        scope(exit) sock.close;
        sock.recvtimeout = 500.msecs;
        foreach(tag; tags) {
            rc = sock.subscribe(tag);
            check(rc == 0, nng_errstr(rc));
        }

        while(!stop) {
            try {
                if(sock.m_state !is nng_socket_state.NNG_STATE_CONNECTED) {
                    rc = sock.dial(address);
                    if(rc != nng_errno.NNG_OK) {
                        Thread.sleep(200.msecs);
                        continue;
                    }
                    stderr.writefln("Listening on %s", address);
                }

                const data = sock.receive!Buffer;
                if (sock.errno == nng_errno.NNG_ETIMEDOUT) {
                    continue;
                }
                check(sock.errno == nng_errno.NNG_OK, nng_errstr(sock.errno));

                long index = data.countUntil('\0');
                check(index > 0, "Message did not begin with a tag");

                Document doc = data[index + 1 .. $];
                if(filter_func(doc)) {
                    sync_write(doc);
                }
            }
            catch(Exception e) {
                sock.close();
                tools.error(e);
            }
        }
    }
    catch(Throwable e) {
        tools.error(e);
    }
    debug stderr.writeln("Stopping");
}
