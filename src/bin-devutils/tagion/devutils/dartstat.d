module tagion.devutils.dartstat;

import std.algorithm : countUntil;
import std.file;
import std.stdio;

import tagion.basic.Types : FileExtension, hasExtension;
import tagion.dart.DART;
import tagion.dart.DARTFile;
import tagion.script.common;
import tagion.crypto.SecureNet;

int _main(string[] args) {

    const dart_file_index = args.countUntil!(file => file.hasExtension(FileExtension.dart) && file.exists);

    if (dart_file_index < 0) {
        stderr.writeln("Missing dart file argument or file doesn't exists");
        return 1;
    }
    const dartfilename = args[dart_file_index];

    auto net = new StdSecureNet;
    Exception dart_exception;
    auto db = new DART(net, dartfilename, dart_exception);

    scope (exit) {
        db.close;
    }

    return 0;
}
