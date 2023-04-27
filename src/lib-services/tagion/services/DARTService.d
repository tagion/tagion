module tagion.services.DartService;

import std.path : isValidPath;
import std.format : format;

import tagion.actor;
import tagion.crypto.Types;
import tagion.crypto.SecureNet;
import tagion.dart.DART;
import tagion.dart.Recorder;

struct DartService {
static:
    DART db;
    StdSecureNet net;

    void starting(const(string) dart_path, const(string) password)
    in {
        assert(dart_path.isValidPath, format("%s is not a valid path"));
    }
    do {
        net = new StdSecureNet;
        net.generateKeyPair(password);

        db = new DART(net, dart_path);
    }

    void _(Msg!"dartRead", Fingerprint fingerprint) {
    }

    void _(Msg!"dartRim", DART.Rims rims) {
    }

    void _(Msg!"dartModify", RecordFactory.Recorder recorder) {
    }

    void _(Msg!"dartBullseye") {
    }

    mixin Actor!(&_);
}

alias DartServiceHandle = ActorHandle!DartService;
