module tagion.devutils.dartstat;

import std.algorithm : countUntil;
import std.file;
import std.stdio;
import std.traits;
import std.typetuple;
import std.array;

import tagion.basic.Types : Buffer, FileExtension, hasExtension;
import tagion.dart.BlockFile;
import tagion.dart.DART;
import tagion.dart.DARTFile;
import tagion.dart.DARTBasic;
import tagion.script.common;
import tagion.crypto.SecureNet;
import tagion.hibon.Document;
import tagion.hibon.HiBONRecord;

alias darttypes = AliasSeq!(
        TagionBill,
        GenesisEpoch,
        Epoch,
        TagionHead,
        TagionGlobals,
);

struct Statistic {
    uint count;
    uint size;
}

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

    Statistic[string] statistics;

    void addStat(string recordname, ulong size) {
        auto entry = recordname in statistics;
        if (entry is null) {
            entry = new Statistic();
        }
        entry.count++;
        entry.size += size;
    }

    bool dartTraverse(const(Document) doc, const Index index, const uint rim, Buffer rim_path) {
        static foreach (alias type; darttypes) {
            if (doc.isRecord!type) {
                const recordname = (fullyQualifiedName!type).split(".")[$ - 1];
                addStat(recordname, doc.full_size);
            }
        }
        return false;
    }

    db.traverse(&dartTraverse);

    foreach (key, value; statistics) {
        writeln(key, ":", value);
    }

    return 0;
}
