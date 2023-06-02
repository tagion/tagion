module tagion.services.DARTService;

import std.path : isValidPath;
import std.format : format;

import tagion.actor;
import std.stdio;
import tagion.crypto.Types;
import tagion.crypto.SecureInterfaceNet;
import tagion.dart.DART;
import tagion.dart.Recorder;
import std.path;
import std.file;

struct DARTService {

    DART db;

    static void dartRead(Msg!"dartRead", Fingerprint fingerprint) {
    }

    static void dartRim(Msg!"dartRim", DART.Rims rims) {
    }

    static void dartModify(Msg!"dartModify", RecordFactory.Recorder recorder) {
    }

    static void dartBullseye(Msg!"dartBullseye") {
    }
    
    void task(string task_name, string dart_path, SecureNet net) nothrow {
        try {

            db = new DART(net, dart_path);

            if(!dart_path.exists) {
                dart_path.dirName.mkdirRecurse;
                DART.create(dart_path);
            }

            run(task_name, &dartRead, &dartRim, &dartModify, &dartBullseye);
            end(task_name);
        }
        catch (Exception e) {
            fail(task_name, e);
        }
    }
}

alias DARTServiceHandle = ActorHandle!DARTService;
