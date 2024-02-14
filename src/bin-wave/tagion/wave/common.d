/**
 * Common utilities for all tagionwave network modes
**/
module tagion.wave.common;

@safe:

import std.sumtype;
import std.range;

import tagion.basic.tagionexceptions;
import tagion.hibon.Document;
import tagion.hibon.HiBONRecord;
import tagion.services.options;
import tagion.services.exception;
import tagion.communication.HiRPC;
import CRUD = tagion.dart.DARTcrud;
import tagion.dart.DART;
import tagion.dart.DARTBasic;
import tagion.script.common;
import tagion.script.standardnames;
import tagion.crypto.SecureNet;
import tagion.crypto.Types;

TagionHead getHead(DART db, const SecureNet net) {
    DARTIndex tagion_index = net.dartKey(StdNames.name, TagionDomain);
    auto hirpc = HiRPC(net);
    const sender = CRUD.dartRead([tagion_index], hirpc);
    const receiver = hirpc.receive(sender);
    auto response = db(receiver, false);
    auto recorder = db.recorder(response.result);

    return TagionHead(recorder[].front.filed);
}

GenericEpoch getEpoch(const TagionHead head, DART db, const SecureNet net) {
    DARTIndex epoch_index = net.dartKey(StdNames.epoch, head.current_epoch);

    const hirpc = HiRPC(net);
    const _sender = CRUD.dartRead([epoch_index], hirpc);
    const _receiver = hirpc.receive(_sender);
    const epoch_response = db(_receiver, false);
    const epoch_recorder = db.recorder(epoch_response.result);
    check!ServiceException(!epoch_recorder[].empty, "There was no Archive at the index pointed to by head");
    const epoch_doc = epoch_recorder[].front.filed;
    if (epoch_doc.isRecord!Epoch) {
        return GenericEpoch(Epoch(epoch_doc));
    }
    else if (epoch_doc.isRecord!GenesisEpoch) {
        return GenericEpoch(GenesisEpoch(epoch_doc));
    }
    throw new ServiceException("The document pointed to by head was neither an Epoch or a GenesisEpoch");
}

// Get the public keys of the nodes which would be running the network
inout(Pubkey)[] getNodeKeys(inout GenericEpoch epoch_head) pure nothrow {
    return epoch_head.match!(
            (inout Epoch epoch) { return epoch.active; },
            (inout GenesisEpoch epoch) { return epoch.nodes; }
    );
}

GenericEpoch getCurrentEpoch(string dart_file_path, SecureNet __net) {
    import tagion.dart.DART;
    import tagion.logger;

    Exception dart_exception;
    DART db = new DART(__net, dart_file_path, dart_exception, Yes.read_only);
    if (dart_exception !is null) {
        throw dart_exception;
    }
    scope (exit) {
        db.close;
    }

    const head = getHead(db, __net);
    log("Tagion head:\n%s", head.toPretty);
    GenericEpoch epoch = head.getEpoch(db, __net);
    epoch.match!(
            (const Epoch e) { log("Current epoch:\n%s", e.toPretty); },
            (const GenesisEpoch e) { log("GenesisEpoch epoch:\n%s", e.toPretty); },
    );

    return epoch;
}
