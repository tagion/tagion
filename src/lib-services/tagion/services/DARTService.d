module tagion.services.DARTService;

import std.path : isValidPath;
import std.format : format;

import tagion.actor;
import std.stdio;
import tagion.crypto.Types;
import tagion.crypto.SecureNet;
import tagion.dart.DART;
import tagion.dart.Recorder;

struct DARTService {
    static void dartRead(Msg!"dartRead", Fingerprint fingerprint) {
    }

    static void dartRim(Msg!"dartRim", DART.Rims rims) {
    }

    static void dartModify(Msg!"dartModify", RecordFactory.Recorder recorder) {
    }

    static void dartBullseye(Msg!"dartBullseye") {
    }
    
    void task(string task_name, string dart_path, string password) nothrow 
        in {
            assert(dart_path.isValidPath, format("%s is not a valid path"));
        }
        do {
            try {
            DART db;
            StdSecureNet net;

            net = new StdSecureNet;
            net.generateKeyPair(password);

            db = new DART(net, dart_path);

            run(task_name, &dartRead, &dartRim, &dartModify, &dartBullseye);
            end(task_name);

            }
            catch (Exception e) {
                return;
            }
    }
}

alias DARTServiceHandle = ActorHandle!DARTService;
