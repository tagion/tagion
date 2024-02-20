module tagion.tools.vergangenheit.Rebuild;
import std.stdio;
import std.algorithm;
import std.range;
import std.format;
import std.typecons;
import std.path;
import std.file : mkdirRecurse;

import tagion.basic.Types;
import tagion.basic.basic;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.Types : Fingerprint;
import tagion.dart.DART;
import tagion.dart.DARTBasic;
import tagion.hibon.HiBONFile;
import tagion.hibon.Document;
import tagion.hibon.HiBONRecord : HiBONRecord;
import tagion.replicator.RecorderBlock;
import tagion.tools.Basic;
import tagion.script.common;
import tagion.tools.toolsexception;
import tagion.script.standardnames;

struct RebuildOptions {
    bool skip_check;
    string path;
}

struct Rebuild {
    const RebuildOptions opt;
   // private {
        DART src;
        DART dst;
        string[] replicator_files;
    //}
    const(LockedArchives)[] locked_epochs;
    this(const RebuildOptions opt, DART src, DART dst, string[] replicator_files) pure nothrow {
        this.opt = opt;
        this.src = src;
        this.dst = dst;
        this.replicator_files=replicator_files;
    }

    void sortReplicator(const HashNet net)  {
        alias ReplicatorFile=Tuple!(size_t, "epoch", string, "file");
        ReplicatorFile[] replicator_list;
        foreach(file; replicator_files) {
            auto fin=File(file, "r");
            scope(exit) {
                fin.close;    
            }
            const block=RecorderBlock(HiBONRange(fin).front, net);
            replicator_list~=ReplicatorFile(block.epoch_number, file);
        }
        replicator_list.sort!((a,b) => a.epoch < b.epoch);
        replicator_files=replicator_list.map!(a => a.file).array;
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
                    error("Replicator epoch-number %d block %d in %s does previous fingerprint",
                    block.epoch_number,item.index, file);
                    verbose("Previous fingerprint");
                    verbose("expected    %s", previous.encodeBase64);
                    //verbose("read        %s", net.calcHash(item.value).encodeBase64);
                    verbose("hibonrecord %s", block.previous.encodeBase64);

                }
            }
            if (block.bullseye.length != net.hashSize) {
                error("Bullseye is not a valid has in block %s for file %s", item.index, file);
            }
            const recorder = src.recorder(block.recorder_doc);

            Epoch[] epochs;
            LockedArchives locked_epoch;
            foreach (archive; recorder[]) {
                const doc = archive.filed;
                if (Epoch.isRecord(doc)) {
                    epochs ~= Epoch(doc);
                }
                else if (archive.isAdd && LockedArchives.isRecord(doc)) {
                    if (!locked_epoch.isinit) {
                        writefln("More than one %s", block.recorder_doc.toPretty);
                    }
                    check(locked_epoch.isinit,
                            format("More than one %s in recorder %d in replicator file %s",
                            LockedArchives.stringof, item.index, file));
                    locked_epoch = LockedArchives(doc);
                }

            }
            auto epoch_dartindices = epochs.map!(epoch => net.dartIndex(epoch)).array;
            auto locked_epoch_dartindex = [net.dartIndex(locked_epoch)];
            const not_in_dart = src.checkload(epoch_dartindices ~ locked_epoch_dartindex);

            if (!not_in_dart.canFind(locked_epoch_dartindex)) {
                locked_epochs ~= locked_epoch;
            }
            previous = Fingerprint(block.fingerprint);
        }

        return result;
    }

    void prepareFromFile(const HashNet net, const string file, ref Fingerprint previous, const long current_epoch) {
        auto fin = File(file, "r");
        scope (exit) {
            fin.close;
        }
        int result;
        //Fingerprint result;
        //foreach(doc; HiBONRange(fin)) {
        File fout;
        scope(exit) {
            fout.close;    
    }
        foreach (item; HiBONRange(fin).enumerate) {
            auto block = RecorderBlock(item.value, net);
            if ((block.epoch_number-current_epoch) >= 1) {
                if (fout is File.init) {
                    const new_file=buildPath(opt.path, format("%010d_epoch", block.epoch_number)).setExtension(FileExtension.hibon);
                    fout=File(new_file, "w");
                    verbose("write %s", new_file);
                }
                fout.fwrite(block);
                auto recorder=dst.recorder(block.recorder_doc);
                dst.modify(recorder);
            }
            
        }
     }

    void prepareReplicator(const HashNet hash_net) {
        const tagion_dartindex=hash_net.dartKey(StdNames.name, TagionDomain);
        const tagion_recorder=dst.loads([tagion_dartindex]);
        check(!tagion_recorder[].empty, 
    format("Destination DART is missing %s", TagionHead.type_name)); 
        const tagion_head=TagionHead(tagion_recorder[].front.filed); 
        writefln("Tagion head=%s", tagion_head.toPretty);
        //foreach(archive; tagion_recorder[]) {
        //    writefln("filed=%s", archive.filed.toPretty);    
    //}
        locked_epochs = null;
        Fingerprint fingerprint;
        int result;
        if (!opt.skip_check) {
        foreach (file; replicator_files) {
            verbose("check file %s", file);
            const error_count = checkReplicator(hash_net, file, fingerprint);
            result += error_count;
        }
    }
        if (result > 0) {
            error("Counted %d errors", result);
        }
        auto locked_epoch_numbers = locked_epochs.map!(l => cast(long) l.epoch_number).array.sort;
       // writefln("locked_epoch_numbers=%s", locked_epoch_numbers.splitWhen!((a, b) => a + 1 != b));
        auto locked_groups = locked_epoch_numbers.splitWhen!((a, b) => a + 1 != b);
        writefln("%(Locked epochs %(%s, %)\n%)", locked_groups);
        mkdirRecurse(opt.path);
        fingerprint=Fingerprint.init; 
        foreach(file; replicator_files) {
            verbose("play file %s", file);
           prepareFromFile( hash_net, file, fingerprint, tagion_head.current_epoch);
                
        }
        //locked_groups.each!(list => writefln("Locked epochs %(%d %)", list));

    }

    //void rebuild(const RebuildOptions opt, DART src, DART dst, string[]
}
