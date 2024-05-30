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
import tagion.services.subscription : SubscriptionServiceOptions;
import tools = tagion.tools.Basic;
import tagion.tools.revision;

import std.exception;
import tagion.crypto.SecureInterfaceNet;
import tagion.communication.HiRPC;
import tagion.utils.Result;
import tagion.logger.ContractTracker : ContractStatus;
import tagion.logger.subscription;
import tagion.hibon.HiBONRecord : isRecord;

mixin tools.Main!_main;

enum SubFormat {
    pretty, // still json but formatted
    json,
    hibon,
}

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
    string address = default_sub_opts.address;
    bool version_switch;
    string tagsRaw;
    string outputfilename;
    SubFormat output_format;
    string contract;

    auto main_args = getopt(args,
        "version", "Print revision information", &version_switch,
        "v|verbose", "Enable verbose print-out", &tools.__verbose_switch,
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
    auto sub = SubscriptionHandle(address, tags);
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
                const payload = result.get["$msg"].get!Document["params"].get!SubscriptionPayload;
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
