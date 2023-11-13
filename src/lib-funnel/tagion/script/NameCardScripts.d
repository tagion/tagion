module tagion.script.NameCardScripts;

import std.typecons;
import tagion.basic.Types : Buffer, FileExtension;
import tagion.communication.HiRPC;
import tagion.crypto.SecureInterfaceNet : HashNet;
import tagion.dart.DART;
import tagion.dart.DARTFile;
import tagion.dart.Recorder;
import tagion.gossip.AddressBook;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord;

Nullable!T readStandardRecord(T)(
        const(HashNet) net,
        HiRPC hirpc,
        DART db,
        Buffer hash,
) if (isHiBONRecord!T) {

    const(Document) readDocFromDB(Buffer[] fingerprints, HiRPC hirpc, DART db) {
        const sender = DART.dartRead(fingerprints, hirpc);
        auto receiver = hirpc.receive(sender.toDoc);
        return db(receiver, false).message["result"].get!Document;
    }

    Nullable!T fromArchive(T)(const(Archive) archive) if (isHiBONRecord!T) {
        if (archive is Archive.init) {
            return Nullable!T.init;
        }
        else {
            return Nullable!T(T(archive.filed));
        }
    }

    auto factory = RecordFactory(net);

    return fromArchive!T(
            factory.recorder(readDocFromDB([hash], hirpc, db))[].doFront
    );
}
