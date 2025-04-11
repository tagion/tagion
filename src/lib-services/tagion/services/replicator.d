/// The replicator creates a backup of all dart transactions
/// https://docs.tagion.org/tech/architecture/Replicator
module tagion.services.replicator;

import std.algorithm;
import std.exception;
import std.file : append, exists, mkdirRecurse;
import std.format;
import std.path : buildPath, setExtension;
import std.range;
import std.stdio;

import tagion.actor;
import tagion.basic.Types : FileExtension;
import tagion.communication.HiRPC;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.SecureNet : StdHashNet;
import tagion.crypto.Types : Fingerprint;
import tagion.dart.Recorder : RecordFactory;
import tagion.errors.tagionexceptions;
import tagion.hibon.Document;
import tagion.hibon.HiBONException;
import tagion.hibon.HiBONFile;
import tagion.logger.Logger;
import tagion.replicator.RecorderBlock;
import tagion.services.messages;
import tagion.json.JSONRecord;

@safe
struct ReplicatorOptions {
    string folder_path = "./recorder";
    int new_file_interval = 10_000;

    void setPrefix(string prefix) nothrow {
        folder_path ~= prefix;
    }

    mixin JSONRecord;
}

enum modify_log = "modify/replicator";

@safe
struct ReplicatorService {
    static Topic modify_recorder = Topic(modify_log);
    const HiRPC hirpc = HiRPC(null);

    void task(immutable(ReplicatorOptions) opts) {
        HashNet net = new StdHashNet;
        RecorderBlock last_block;
        string filepath;
        File file;

        scope (exit)
            file.close;

        void receiveReplicatorFilePath(repFilePathRR req) {
            req.respond(filepath);
        }

        void readRecorder(readRecorderRR req, Document doc) {
            import tagion.replicator.RecorderCrud;
            import tagion.hibon.HiBONJSON : toPretty;

            try {
                const receiver = hirpc.receive(doc);
                const epoch_number = receiver.params!(EpochParam).epoch_number;
                auto fin = File(filepath, "r");
                scope (exit)
                    fin.close;
                foreach (item; HiBONRange(fin)) {
                    auto block = RecorderBlock(item, net);
                    if (block.epoch_number == epoch_number) {
                        req.respond(block.toDoc);
                        break;
                    }
                }
            }
            catch (Exception e) {
                log("readRecorder error: %s", e.msg);
            }
        }

        void receiveRecorder(
            SendRecorder,
            immutable(RecordFactory.Recorder) recorder,
            Fingerprint bullseye,
            immutable long epoch_number
        ) {
            if (file is File.init || epoch_number % opts.new_file_interval == 0) {
                log("Creating new file for epoch %d", epoch_number);

                if (file !is File.init) {
                    file.close;
                }

                const filename = format("%010d_epoch", epoch_number).setExtension(
                    FileExtension.hibon);
                filepath = buildPath(opts.folder_path, filename);

                if (!opts.folder_path.exists) {
                    mkdirRecurse(opts.folder_path);
                }

                if (filepath.exists) {
                    throw new TagionException(format("File already exists: %s", filepath));
                }

                file = File(filepath, "w");
            }

            auto block = RecorderBlock(
                recorder.toDoc,
                last_block is RecorderBlock.init ? Fingerprint.init
                    : last_block.fingerprint,
                    bullseye,
                    epoch_number,
                    net
            );

            scope (success) {
                file.fwrite(block);
                file.flush;
                last_block = block;
            }

            log.trace("Added recorder block with hash '%(%02x%)'", block.fingerprint);
            log.event(modify_recorder, "modify", recorder);
        }

        run(&receiveRecorder, &readRecorder, &receiveReplicatorFilePath);
    }
}
