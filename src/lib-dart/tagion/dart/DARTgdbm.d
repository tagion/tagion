module tagion.dart.DARTgdbm;

import std.typecons;

import tagion.basic.Types;
import tagion.crypto.StdSecureNet;
import tagion.dart.gdbm;
import tagion.dart.Recorder;
import tagion.dart.DARTcrud;
import tagion.dart.DARTBasic;
import tagion.dart.RimKeyRange;
import tagion.hibon.Document;

class DARTFile {
    protected GDBM db_file;
    SecureNet net;
    Fingerprint _fingerprint;

    Fingerprint modify(const(RecordFactory.Recorder) modifyrecords, const Flag!"undo" undo = No) {
        auto range = rimKeyRange(modifyrecords);
        foreach(archive; modifyrecords[]) {
            final switch (archive.type) with(Archive.Type) {
                case NONE, ADD:
                    db.store(archive.dart_index, archive.filed);
                    break;
                case REMOVE:
                    db.remove(archive.dart_index);
                    break;
            }
        }
        db.sync();
    }
}
