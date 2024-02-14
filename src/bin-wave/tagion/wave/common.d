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
Pubkey[] getNodeKeys(GenericEpoch epoch_head) {
    return epoch_head.match!(
            (Epoch epoch) { return epoch.active; },
            (GenesisEpoch epoch) { return epoch.nodes; }
    );
}
