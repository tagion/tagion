module tagion.tools.vergangenheit.Rebuild;
import std.stdio;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.Types : Fingerprint;
import tagion.dart.DART;
import tagion.hibon.HiBONFile;

struct RebuildOptions {
}

struct Rebuild {
    const RebuildOptions opt;
    private {
        DART src;
        DART dst;
        string[] replicator_files;
    }
    this(const RebuildOptions opt, DART src, DART dst) pure nothrow {
        this.opt = opt;
        this.src = src;
        this.dst = dst;
    }

    static Fingerprint checkReplicator(const HashNet net, const string file)  {
        auto fin = File(file, "r");
        scope (exit) {
            fin.close;
        }
        Fingerprint result;
        foreach(doc; HiBONRange(fin)) {
                
        }

        return result;
    }

    void prepareReplicator(string[] replicator_files) {

    }

    //void rebuild(const RebuildOptions opt, DART src, DART dst, string[]
}
