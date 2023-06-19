module tagion.services.DART;

import std.path : isValidPath;
import std.format : format;
import std.file;

import tagion.actor;
import std.stdio;
import tagion.crypto.Types;
import tagion.crypto.SecureInterfaceNet;
import tagion.dart.DART;
import tagion.dart.Recorder;
import tagion.dart.DARTBasic : DARTIndex;

struct DARTService {
    static DART db;
    static void dartRead(Msg!"dartRead", Fingerprint fingerprint) {
    }

    static void dartRim(Msg!"dartRim", DART.Rims rims) {
    }

    static void dartModify(Msg!"dartModify", RecordFactory.Recorder recorder) {
    }

    static void dartBullseye(Msg!"dartBullseye") {
        sendOwner(DARTIndex(db.bullseye));
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
