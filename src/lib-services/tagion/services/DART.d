/// Tagion DART actor service
module tagion.services.DART;

import std.path : isValidPath;
import std.format : format;
import std.file;
import std.algorithm : map;
import std.array;
import std.stdio;

import tagion.utils.pretend_safe_concurrency;
import tagion.actor;
import tagion.crypto.Types;
import tagion.crypto.SecureInterfaceNet;
import tagion.dart.DART;
import tagion.dart.Recorder;
import tagion.dart.DARTBasic : DARTIndex;
import tagion.hibon.Document;

/// Response from a dart CRUD call
alias dartResp = Msg!"dartResp";

struct DARTService {
    static DART db;

    // Rssponds immutable Document[]
    static void dartRead(Msg!"dartRead", Tid to, const(DARTIndex)[] fingerprints) {
        auto read_recorder = db.loads(fingerprints);
        const(Document)[] docs = read_recorder[].map!(a => a.filed).array;

        send(to, dartResp(), cast(immutable) docs);
    }

    static void dartRim(Msg!"dartRim", Tid to, DART.Rims rims) {
    }

    static void dartModify(Msg!"dartModify", Tid to, RecordFactory.Recorder recorder) {
    }

    // Responds DARTIndex
    static void dartBullseye(Msg!"dartBullseye", Tid to) {
        send(to, dartResp(), DARTIndex(db.bullseye));
    }

    static void task(string task_name, string dart_path, immutable SecureNet net) nothrow {
        try {
            db = new DART(net, dart_path);
            run(task_name, &dartRead, &dartRim, &dartModify, &dartBullseye);

            db.close();
            end(task_name);
        }
        catch (Exception e) {
            fail(task_name, e);
        }
    }
}

alias DARTServiceHandle = ActorHandle!DARTService;
