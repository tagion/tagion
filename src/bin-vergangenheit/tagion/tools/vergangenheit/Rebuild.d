module tagion.tools.vergangenheit.Rebuild;
import std.stdio;
import std.algorithm;
import std.range;
import tagion.basic.Types;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.Types : Fingerprint;
import tagion.dart.DART;
import tagion.hibon.HiBONFile;
import tagion.replicator.RecorderBlock;
import tagion.tools.Basic;

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

    static int checkReplicator(const HashNet net, const string file, ref Fingerprint previous) {
        auto fin = File(file, "r");
        scope (exit) {
            fin.close;
        }
        int result;
        //Fingerprint result;
        //foreach(doc; HiBONRange(fin)) {
        foreach (item; HiBONRange(fin).enumerate) {
            const block = RecorderBlock(item.value, net);
            if (!previous.empty) {
                if (block.previous != previous) {
                    result++;
                    error("Replicator block %d in %s does previous fingerprint", item.index, file);
                    verbose("Previous fingerprint");
                    verbose("expected    %s", previous.encodeBase64);
                    verbose("read        %s", net.calcHash(item.value).encodeBase64);
                    verbose("hibonrecord %s", block.previous.encodeBase64);

                }
            }
            previous = Fingerprint(block.fingerprint);
        }

        return result;
    }

    void prepareReplicator(const HashNet hash_net, string[] replicator_files) {
        Fingerprint fingerprint;
        foreach(file; replicator_files) {
           checkReplicator(hash_net, file, fingerprint);
        }
    }

    //void rebuild(const RebuildOptions opt, DART src, DART dst, string[]
}
