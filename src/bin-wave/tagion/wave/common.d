/**
 * Common utilities for all tagionwave network modes
**/
module tagion.wave.common;

import std.stdio;

import tagion.hibon.Document;
import tagion.services.options;
import tagion.communication.HiRPC;
import CRUD = tagion.dart.DARTcrud;
import tagion.dart.DART;
import tagion.dart.DARTBasic;
import tagion.script.common;
import tagion.script.standardnames;
import tagion.crypto.SecureNet;

Document getHead(const Options node_options, SecureNet __net) {
    import std.typecons;

    Exception dart_exception;
    DART db = new DART(__net, node_options.dart.dart_path, dart_exception, Yes.read_only);
    if (dart_exception !is null) {
        throw dart_exception;
    }
    scope (exit) {
        db.close;
    }

    // read the databases TAGIONHEAD
    DARTIndex tagion_index = __net.dartKey(StdNames.name, TagionDomain);
    auto hirpc = HiRPC(__net);
    const sender = CRUD.dartRead([tagion_index], hirpc);
    const receiver = hirpc.receive(sender);
    auto response = db(receiver, false);
    auto recorder = db.recorder(response.result);

    Document doc;
    if (!recorder.empty) {
        const head = TagionHead(recorder[].front.filed);
        writefln("Found head: %s", head.toPretty);

        pragma(msg, "fixme(phr): count the keys up hardcoded to be genesis atm");
        DARTIndex epoch_index = __net.dartKey(StdNames.epoch, long(0));
        writefln("epoch index is %(%02x%)", epoch_index);

        const _sender = CRUD.dartRead([epoch_index], hirpc);
        const _receiver = hirpc.receive(_sender);
        auto epoch_response = db(_receiver, false);
        auto epoch_recorder = db.recorder(epoch_response.result);
        doc = epoch_recorder[].front.filed;
        writefln("Epoch_found: %s", doc.toPretty);
    }
    return doc;
}
