/// The replicator creates a backup of all dart transactions
/// https://docs.tagion.org/tech/architecture/Replicator
module tagion.services.replicator;

import tagion.actor;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.SecureNet : StdHashNet;
import tagion.crypto.Types : Fingerprint;
import tagion.dart.Recorder : RecordFactory;
import tagion.logger.Logger;
import tagion.replicator.RecorderBlock;
import tagion.services.messages;

//import tagion.utils.convert : cutHex;
import tagion.basic.Types : FileExtension;
import tagion.errors.tagionexceptions;
import std.path : buildPath, setExtension;
import std.stdio;
import std.format;
import std.file : append, exists, mkdirRecurse;
import tagion.hibon.HiBONFile;
import tagion.hibon.HiBONException;
import std.algorithm;
import tagion.hibon.Document;
import tagion.communication.HiRPC;

@safe
struct ReplicatorOptions {
    import std.format;
    import tagion.json.JSONRecord;

    string folder_path = "./recorder";
    int new_file_interval = 10_000;

    void setPrefix(string prefix) nothrow {
        import std.exception;
        import std.path : buildPath;

        folder_path = folder_path ~ prefix;
        // assumeWontThrow(buildPath(folder_path, prefix));
    }

    mixin JSONRecord;
}

enum modify_log = "modify/replicator";

@safe
struct ReplicatorService {
    static Topic modify_recorder = Topic(modify_log);
    const hirpc = HiRPC(null);

    void task(immutable(ReplicatorOptions) opts) {
        HashNet net = new StdHashNet;
        RecorderBlock last_block;
        string filepath;

        File file;
        scope (exit) {
            file.close;
        }

        void receiveReplicatorFilePath(repFilePathRR req) {
            req.respond(filepath);
        }

        void readRecorder(readRecorderRR req, Document doc) {
            import std.range;
            import tagion.replicator.RecorderCrud;

            try {
                const receiver = hirpc.receive(doc);

                // log("ReadRecorder receiver: %s", receiver.toPretty);
                const epoch_number = receiver.params!(EpochParam).epoch_number;

                auto fin = File(filepath, "r");
                scope (exit) {
                    fin.close;
                }

                foreach (item; HiBONRange(fin)) {
                    auto block = RecorderBlock(item, net);

                    if (block.epoch_number == epoch_number) {
                        req.respond(block.toDoc);
                        break;
                    }
                }
            }
            catch (Exception e) {
                log("Received readRecorderRR request: %s", e.msg);
            }
        }

        void receiveRecorder(SendRecorder, immutable(RecordFactory.Recorder) recorder, Fingerprint bullseye, immutable(
                long) epoch_number) {

            if (file is File.init || epoch_number % opts.new_file_interval == 0) {
                log("going to create new file");
                if (file !is File.init) {
                    file.close;
                }
                const filename = format("%010d_epoch", epoch_number).setExtension(
                    FileExtension.hibon);
                filepath = buildPath(opts.folder_path, filename);
                log.trace("Creating new replicator file %s", filepath);

                if (!opts.folder_path.exists) {
                    mkdirRecurse(opts.folder_path);
                }

                if (filepath.exists) {
                    throw new TagionException(format("Error: File %s already exists", filepath));
                }
                file = File(filepath, "w");
            }
            RecorderBlock block;
            scope (success) {
                file.fwrite(block);
                file.flush;
                last_block = block;
            }

            block = RecorderBlock(
                recorder.toDoc,
                last_block is RecorderBlock.init ? Fingerprint.init
                    : last_block.fingerprint,
                    bullseye,
                    epoch_number,
                    net);

            log.trace("Added recorder chain block with hash '%(%02x%)'", block.fingerprint);
            log.event(modify_recorder, "modify", recorder);
        }

        run(&receiveRecorder, &readRecorder, &receiveReplicatorFilePath);
    }
}
