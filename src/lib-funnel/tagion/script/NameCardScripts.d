module tagion.script.NameCardScripts;

import std.typecons;

import tagion.dart.DART;
import tagion.dart.DARTFile;
import tagion.basic.Types : Buffer, FileExtension;

import tagion.communication.HiRPC;
import tagion.gossip.AddressBook;
import tagion.crypto.SecureInterfaceNet : HashNet;
import tagion.hibon.Document;
import tagion.hibon.HiBONRecord;
import tagion.hibon.HiBONJSON;

import tagion.dart.Recorder;
import tagion.script.StandardRecords;

import tagion.basic.Basic : doFront;

private const(Document) readDocFromDB(Buffer[] fingerprints, HiRPC hirpc, DART db) {
    const sender = DART.dartRead(fingerprints, hirpc);
    auto receiver = hirpc.receive(sender.toDoc);
    return db(receiver, false).message["result"].get!Document;
}

private Nullable!T fromArchive(T)(const(Archive) archive) if (isHiBONRecord!T) {
    if (archive is Archive.init) {
        return Nullable!T.init;
    }
    else {
        return Nullable!T(T(archive.filed));
    }
}

void readNetworkNameCard(
    const(HashNet) net, 
    HiRPC hirpc, 
    DART db, 
    string nnc_name,
    ref Nullable!NetworkNameCard nnc_out,
    ref Nullable!HashLock signature_out,
    ref Nullable!NetworkNameRecord nrc_out,
    ref Nullable!NodeAddress node_addr_out
    ) {

    auto factory = RecordFactory(net);

    NetworkNameCard nnc_find;
    nnc_find.name = nnc_name;

    nnc_out = fromArchive!NetworkNameCard(
        factory.recorder(readDocFromDB([net.hashOf(nnc_find)], hirpc, db))
            [].doFront
        );
    if (!nnc_out.isNull) {
        auto nnc = nnc_out.get;

        signature_out = fromArchive!HashLock(
            factory.recorder(readDocFromDB([net.hashOf(HashLock(net, nnc))], hirpc, db))
                [].doFront
            );

        nrc_out = fromArchive!NetworkNameRecord(
            factory.recorder(readDocFromDB([nnc.record], hirpc, db))
                [].doFront
            );
        if (!nrc_out.isNull) {
            auto nrc = nrc_out.get;

            node_addr_out = fromArchive!NodeAddress(
                factory.recorder(readDocFromDB([nrc.node], hirpc, db))
                    [].doFront
                );
        }
    }
}