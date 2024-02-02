module tagion.tools.vergangenheit.Rebuild;
import std.stdio;
import std.algorithm;
import std.range;
import std.format;
import tagion.basic.Types;
import tagion.basic.basic;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.Types : Fingerprint;
import tagion.dart.DART;
import tagion.dart.DARTBasic;
import tagion.hibon.HiBONFile;
import tagion.hibon.Document;
import tagion.hibon.HiBONRecord;
import tagion.replicator.RecorderBlock;
import tagion.tools.Basic;
import tagion.script.common;
import tagion.tools.toolsexception;

struct RebuildOptions {
}

struct Rebuild {
    const RebuildOptions opt;
    private {
        DART src;
        DART dst;
        string[] replicator_files;
    }
    const(LockedArchives)[] locked_epochs;
    this(const RebuildOptions opt, DART src, DART dst) pure nothrow {
        this.opt = opt;
        this.src = src;
        this.dst = dst;
    }

    int checkReplicator(const HashNet net, const string file, ref Fingerprint previous) {
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
            if (block.bullseye.length != net.hashSize) {
                error("Bullseye is not a valid has in block %s for file %s", item.index, file);
            }
            const recorder = src.recorder(block.recorder_doc);

            Epoch epoch;
            LockedArchives locked_epoch;
            foreach (archives; recorder[]) {
                const doc = archives.filed;
                if (Epoch.isRecord(doc)) {
                    check(epoch.isinit, 
                        format("More than one %s in recorder %d in replicator file %s", 
                Epoch.stringof, item.index, file));
                    epoch = Epoch(doc);
                }
                else if (LockedArchives.isRecord(doc)) {
                    check(locked_epoch.isinit, 
                        format("More than one %s in recorder %d in replicator file %s", 
                LockedArchives.stringof, item.index, file));
                    locked_epoch = LockedArchives(doc);
                }

            }
            const epoch_dartindex=net.dartIndex(epoch);
            const locked_epoch_dartindex=net.dartIndex(locked_epoch);
            const not_in_dart=src.checkload([epoch_dartindex, locked_epoch_dartindex]); 
            locked_epochs ~= locked_epoch;
            previous = Fingerprint(block.fingerprint);
        }

        return result;
    }

    void prepareReplicator(const HashNet hash_net, string[] replicator_files) {
        locked_epochs = null;
        Fingerprint fingerprint;
        int result;
        foreach (file; replicator_files) {
            verbose("file %s", file);
            const error_count = checkReplicator(hash_net, file, fingerprint);
            result += error_count;
        }
        if (result > 0) {
            error("Counted %d errors", result);
        }
        auto locked_epoch_numbers = locked_epochs.map!(l => cast(long) l.epoch_number).array.sort;
        writefln("locked_epoch_numbers=%s", locked_epoch_numbers);

    }

    //void rebuild(const RebuildOptions opt, DART src, DART dst, string[]
}
