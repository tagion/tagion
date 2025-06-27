/**
 * Common utilities for all tagionwave network modes
**/
module tagion.wave.common;

@safe:

import std.sumtype;
import std.range;
import std.algorithm;

import tagion.errors.tagionexceptions;
import tagion.hibon.Document;
import tagion.hibon.HiBONRecord;
import tagion.services.options;
import tagion.services.exception;
import tagion.communication.HiRPC;
import CRUD = tagion.dart.DARTcrud;
import tagion.dart.DART;
import tagion.dart.DARTBasic;
import tagion.dart.Recorder;
import tagion.script.common;
import tagion.script.standardnames;
import tagion.script.namerecords;
import tagion.crypto.SecureNet;
import tagion.crypto.Types;

TagionHead getHead(DART db, const HashNet net = hash_net) {
    DARTIndex tagion_index = net.dartId(HashNames.domain_name, TagionDomain);
    auto recorder = db.loads([tagion_index]);
    check!ServiceException(recorder[].walkLength == 1, "No tagionhead was found");
    return TagionHead(recorder[].front.filed);
}


GenericEpoch getEpoch(long epoch, DART db, const HashNet net = hash_net) {
    DARTIndex epoch_index = net.dartId(HashNames.epoch, epoch);
    const epoch_recorder = db.loads([epoch_index], Archive.Type.NONE);
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
            (inout Epoch epoch) => epoch.active,
            (inout GenesisEpoch epoch) => epoch.nodes,
    );
}

// Gets the active nodes from a dart
// Reads first the active nodes records or falls back to the GenesisEpoch
Pubkey[] getNodeKeys(DART db, const HashNet net = hash_net) {
    DARTIndex active_index = net.dartId(HashNames.active, TagionDomain);
    const active_recorder = db.loads([active_index], Archive.Type.NONE);
    if(!active_recorder.empty) {
        Active active_record = Active(active_recorder[].front.filed);
        return active_record.nodes;
    }

    DARTIndex epoch_index = net.dartId(HashNames.epoch, long(0));
    const recorder = db.loads([epoch_index], Archive.Type.NONE);
    check(!recorder.empty, "No Active or GenesisEpoch record in dart");
    GenesisEpoch gen_epoch = GenesisEpoch(recorder[].front.filed);
    return gen_epoch.nodes;
}

/// Read the Node names records and put them in the addressbook
/// Sorts the keys
immutable(NetworkNodeRecord)*[] readNNRFromDart(DART db, Pubkey[] keys, const HashNet net = hash_net)
in (equal(keys, keys.uniq), "Is trying to read duplicate node keys")
do {
    import tagion.services.exception;

    auto nodekey_indices = keys.map!(k => net.dartId(HashNames.nodekey, k)).array;
    const recorder = db.loads(nodekey_indices);

    check(recorder.length == nodekey_indices.length, "One or more Network Node Records were not in the dart");
    check(recorder[].each!(a => a.filed.isRecord!NetworkNodeRecord), "The read archives were not a NNR");

    immutable(NetworkNodeRecord)*[] nnrs;
    foreach (a; recorder[]) {
        nnrs ~= new NetworkNodeRecord(a.filed);
    }
    return nnrs;
}
