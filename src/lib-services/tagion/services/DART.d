/// Tagion DART actor service
module tagion.services.DART;

import std.path : isValidPath;
import std.format : format;
import std.file;
import std.algorithm : map;
import std.array;
import std.stdio;
import std.path;

import tagion.utils.pretend_safe_concurrency;
import tagion.utils.JSONCommon;
import tagion.basic.Types : FileExtension;
import tagion.actor;
import tagion.crypto.Types;
import tagion.crypto.SecureInterfaceNet;
import tagion.dart.DART;
import tagion.dart.Recorder;
import tagion.dart.DARTBasic : DARTIndex;
import tagion.hibon.Document;

@safe
struct DARTOptions {
    string dart_filename = buildPath(".", "dart".setExtension(FileExtension.dart));
    mixin JSONCommon;
}
/// Response from a dart CRUD call
alias dartResp = Msg!"dartResp";

struct DARTService {
    DART db;

    // Rssponds immutable Document[]
    void dartRead(Msg!"dartRead", Tid to, const(DARTIndex)[] fingerprints) {
        auto read_recorder = db.loads(fingerprints);
        const(Document)[] docs = read_recorder[].map!(a => a.filed).array;

        send(to, dartResp(), cast(immutable) docs);
    }

    void dartRim(Msg!"dartRim", Tid to, DART.Rims rims) {
    }

    void dartModify(Msg!"dartModify", Tid to, RecordFactory.Recorder recorder) {
    }

    // Responds DARTIndex
    void dartBullseye(Msg!"dartBullseye", Tid to) {
        send(to, dartResp(), DARTIndex(db.bullseye));
    }

    void task(immutable(DARTOptions) opts, immutable(SecureNet) net) {
        db = new DART(net, opts.dart_filename);
        run(&dartRead, &dartRim, &dartModify, &dartBullseye);

        scope (exit) {
            db.close();
        }
    }
}

alias DARTServiceHandle = ActorHandle!DARTService;
